import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as functions from "firebase-functions/v1";

initializeApp();

/**
 * Wipes everything stored for a user once their Auth account is deleted, so the app's own
 * deletion is a single call (delete the Auth user) that either happens or doesn't. Runs
 * with admin rights, outside the security rules, and is retried until it succeeds; every
 * step is safe to repeat.
 *
 * Auth's onDelete trigger only exists in the first-generation API.
 *
 * Covers (see docs/specs/data-and-sync.md): users/{uid} and its private documents, the
 * user's handles/{handle} lock, avatars/{uid}/ in Storage, and their place in every group.
 * Anything new stored per user belongs here too.
 */
export const deleteUserData = functions
  // The Firebase Admin SDK account, which already has Firestore and Storage access: the
  // project has no default Compute Engine account for first-generation functions to use.
  .runWith({ failurePolicy: true, serviceAccount: "firebase-adminsdk-fbsvc@squabble-9c1df.iam.gserviceaccount.com" })
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const db = getFirestore();

    // Found by owner rather than through the profile, so a retry after the profile is gone
    // still releases the handle.
    const handles = await db.collection("handles").where("uid", "==", uid).get();
    const batch = db.batch();
    handles.docs.forEach((handle) => batch.delete(handle.ref));
    await batch.commit();

    await db.recursiveDelete(db.doc(`users/${uid}`));

    const groups = await db.collection("groups").where("memberIds", "array-contains", uid).get();
    for (const group of groups.docs) {
      await leaveAsDeletedMember(group.ref, uid);
    }

    await getStorage().bucket().deleteFiles({ prefix: `avatars/${uid}/` });

    functions.logger.info("Deleted user data", { uid, handles: handles.size, groups: groups.size });
  });

/**
 * Takes a deleted account out of a group without breaking its bills: the uid leaves
 * memberIds, and its entry is reduced to `{ deleted: true }` so old bills can still say
 * "Deleted member". The creator's powers pass to the earliest-joined member who remains
 * (ties go by memberIds order); a group nobody is left in is deleted. See
 * docs/specs/groups.md.
 */
async function leaveAsDeletedMember(group: FirebaseFirestore.DocumentReference, uid: string): Promise<void> {
  const db = getFirestore();
  const isEmpty = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(group);
    const data = snapshot.data();
    if (!data) return false;
    const memberIds: string[] = data.memberIds ?? [];
    if (!memberIds.includes(uid)) return false;

    const remaining = memberIds.filter((id) => id !== uid);
    if (remaining.length === 0) return true;

    const update: Record<string, unknown> = {
      memberIds: remaining,
      [`members.${uid}`]: { deleted: true },
    };
    if (data.createdBy === uid) {
      update.createdBy = earliestJoined(remaining, data.members ?? {});
    }
    transaction.update(group, update);
    return false;
  });
  if (isEmpty) await deleteGroup(group);
}

/** Deletes a group with everything under it, and its photo if it has one. */
async function deleteGroup(group: FirebaseFirestore.DocumentReference): Promise<void> {
  const image = (await group.get()).data()?.image;
  if (image?.kind === "photo" && typeof image.path === "string") {
    // Already gone on a retry; that's fine.
    await getStorage().bucket().file(image.path).delete({ ignoreNotFound: true });
  }
  await getFirestore().recursiveDelete(group);
}

function earliestJoined(memberIds: string[], members: Record<string, { joinedAt?: Timestamp }>): string {
  const joined = (id: string) => members[id]?.joinedAt?.toMillis() ?? Number.MAX_SAFE_INTEGER;
  // Array.prototype.sort is stable, so equal times keep memberIds order.
  return [...memberIds].sort((a, b) => joined(a) - joined(b))[0];
}
