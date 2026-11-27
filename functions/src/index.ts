import { initializeApp } from "firebase-admin/app";
import { FieldPath, FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { randomBytes } from "node:crypto";
import { getStorage } from "firebase-admin/storage";
import * as functions from "firebase-functions/v1";
import { computeBalances, sameBalances, sameIDs } from "./balances";
import { parseRates } from "./rates";

initializeApp();

/**
 * Keeps `groups/{gid}.balances` in step with its bills (docs/specs/bills.md, "Balances").
 * Recomputed from scratch in a transaction rather than added up from changes, so retries and
 * events out of order are harmless.
 */
export const updateBalances = functions
  .runWith({ failurePolicy: true, serviceAccount: "firebase-adminsdk-fbsvc@squabble-9c1df.iam.gserviceaccount.com" })
  .firestore.document("groups/{groupId}/bills/{billId}")
  .onWrite(async (_change, context) => {
    const db = getFirestore();
    const group = db.doc(`groups/${context.params.groupId}`);
    await db.runTransaction(async (transaction) => {
      const data = (await transaction.get(group)).data();
      // The whole group is being deleted.
      if (!data) return;
      const bills = await transaction.get(group.collection("bills"));
      const { balances, invalid, involved } = computeBalances(
        bills.docs.map((bill) => ({ id: bill.id, data: bill.data() })),
        data.currency,
        new Set(Object.keys(data.members ?? {})),
      );
      if (invalid.length > 0) functions.logger.warn("Skipped invalid bills", { group: group.id, invalid });
      if (data.balances && sameBalances(data.balances, balances) && sameIDs(data.involvedIds, involved)) return;
      transaction.update(group, { balances, involvedIds: involved });
    });
  });

/**
 * Keeps `rates/latest` up to date (docs/specs/bills.md, "Exchange rates"). The ECB publishes
 * once a working day; looking a few times makes up for a failed run or a late publication.
 * Written only when there's something new, since every write is a read for every phone.
 */
export const updateRates = functions
  .runWith({ serviceAccount: "firebase-adminsdk-fbsvc@squabble-9c1df.iam.gserviceaccount.com" })
  .pubsub.schedule("0 */6 * * *")
  .timeZone("Europe/Berlin")
  .onRun(async () => {
    const response = await fetch("https://api.frankfurter.dev/v1/latest", { signal: AbortSignal.timeout(20_000) });
    if (!response.ok) throw new Error(`Rates answered ${response.status}`);
    const rates = parseRates(await response.json());
    const latest = getFirestore().doc("rates/latest");
    const current = (await latest.get()).data();
    if (typeof current?.date === "string" && current.date >= rates.date) return;
    await latest.set(rates);
  });

/**
 * Wipes everything stored for a user once their Auth account is deleted, so the app's own
 * deletion is a single call (delete the Auth user) that either happens or doesn't. Runs
 * with admin rights, outside the security rules, and is retried until it succeeds; every
 * step is safe to repeat.
 *
 * Auth's onDelete trigger only exists in the first-generation API.
 *
 * Covers (see docs/specs/data-and-sync.md): users/{uid} and its private documents, the
 * user's handles/{handle} lock, avatars/{uid}/ in Storage, their place in every group, and
 * their chat messages' texts and reactions (and a group's copy of their latest message), and
 * reports: the ones they filed, and the text copied into reports about their messages.
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
      await scrubMessages(group.ref, uid);
      await leaveAsDeletedMember(group.ref, uid);
    }

    await scrubReports(uid);

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
    // The squabble lists quote the latest message; theirs is blanked like the rest.
    const activity = data.lastActivity;
    if (activity?.by === uid && activity.kind === "message") {
      update.lastActivity = { kind: "messageDeleted", by: uid, id: activity.id };
    }
    transaction.update(group, update);
    return false;
  });
  if (isEmpty) await deleteGroup(group);
}

/**
 * Blanks the user's messages in a group and drops their reactions. The messages stay, shown
 * from "Deleted member", so replies to them still make sense (docs/specs/chat.md).
 */
async function scrubMessages(group: FirebaseFirestore.DocumentReference, uid: string): Promise<void> {
  const messages = group.collection("messages");
  const [authored, reacted] = await Promise.all([
    messages.where("authorId", "==", uid).get(),
    messages.where(new FieldPath("reactions", uid), "!=", null).get(),
  ]);
  // One write per message, as a message can be both the user's and reacted to by them.
  const updates = new Map<string, { ref: FirebaseFirestore.DocumentReference; fields: Record<string, unknown> }>();
  const fieldsFor = (message: FirebaseFirestore.QueryDocumentSnapshot) => {
    const entry = updates.get(message.id) ?? { ref: message.ref, fields: {} };
    updates.set(message.id, entry);
    return entry.fields;
  };
  for (const message of authored.docs) {
    const fields = fieldsFor(message);
    fields.text = FieldValue.delete();
    if (!message.get("deletedAt")) fields.deletedAt = FieldValue.serverTimestamp();
  }
  for (const message of reacted.docs) {
    fieldsFor(message)[`reactions.${uid}`] = FieldValue.delete();
  }
  const writer = getFirestore().bulkWriter();
  for (const { ref, fields } of updates.values()) writer.update(ref, fields);
  await writer.close();
}

/**
 * Deletes the reports the user filed, and blanks the message text copied into reports about
 * them, as their messages are blanked. Those reports stay, so a pattern is still visible.
 */
async function scrubReports(uid: string): Promise<void> {
  const reports = getFirestore().collection("reports");
  const [filed, about] = await Promise.all([
    reports.where("reportedBy", "==", uid).get(),
    reports.where("authorId", "==", uid).get(),
  ]);
  const writer = getFirestore().bulkWriter();
  const deleted = new Set(filed.docs.map((report) => report.id));
  for (const report of filed.docs) writer.delete(report.ref);
  for (const report of about.docs) {
    if (!deleted.has(report.id) && report.get("text") !== undefined) {
      writer.update(report.ref, { text: FieldValue.delete() });
    }
  }
  await writer.close();
}

/** Deletes a group with everything under it, its photo if it has one, and its invite. */
async function deleteGroup(group: FirebaseFirestore.DocumentReference): Promise<void> {
  const data = (await group.get()).data();
  const image = data?.image;
  if (typeof data?.inviteCode === "string") {
    await getFirestore().doc(`invites/${data.inviteCode}`).delete();
  }
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

// Invites (docs/specs/groups.md, "Joining with an invite link"). A group's code lives on
// the group (`inviteCode`, so members can show it offline) and in invites/{code} -> groupId,
// which only these functions read or write. Callables run as the Admin SDK account, like
// deleteUserData, because the project has no default Compute Engine account.
const callable = functions.runWith({ serviceAccount: "firebase-adminsdk-fbsvc@squabble-9c1df.iam.gserviceaccount.com" }).https;
const maxMembers = 50;

function requireUid(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

function requireString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 200) {
    throw new functions.https.HttpsError("invalid-argument", `Missing ${name}.`);
  }
  return value;
}

/** 128 random bits, URL-safe. */
function newInviteCode(): string {
  return randomBytes(16).toString("base64url");
}

/** Safe to call twice, or at once: whoever gets there first makes the code. */
async function inviteCodeFor(groupId: string, checkAccess: (group: FirebaseFirestore.DocumentData | undefined) => void): Promise<string | null> {
  const db = getFirestore();
  const group = db.doc(`groups/${groupId}`);
  return db.runTransaction(async (transaction) => {
    const groupData = (await transaction.get(group)).data();
    checkAccess(groupData);
    if (!groupData) return null;
    if (typeof groupData.inviteCode === "string") return groupData.inviteCode;
    const fresh = newInviteCode();
    transaction.set(db.doc(`invites/${fresh}`), { groupId, createdAt: FieldValue.serverTimestamp() });
    transaction.update(group, { inviteCode: fresh });
    return fresh;
  });
}

/**
 * Makes a new squabble's invite link before anyone looks for it. A trigger rather than a call
 * from the app, which would race the squabble's own write to the server.
 */
export const createInviteForNewGroup = functions
  .runWith({ failurePolicy: true, serviceAccount: "firebase-adminsdk-fbsvc@squabble-9c1df.iam.gserviceaccount.com" })
  .firestore.document("groups/{groupId}")
  .onCreate(async (_snapshot, context) => {
    await inviteCodeFor(context.params.groupId, () => {});
  });

/** Returns the squabble's invite code, creating one if it has none yet. */
export const createInvite = callable.onCall(async (data, context) => {
  const uid = requireUid(context);
  const code = await inviteCodeFor(requireString(data?.groupId, "groupId"), (group) => {
    if (!group || !(group.memberIds ?? []).includes(uid)) {
      throw new functions.https.HttpsError("permission-denied", "Not a member.");
    }
    if (group.archivedAt) throw new functions.https.HttpsError("failed-precondition", "archived");
  });
  return { code };
});

/** The creator kills the current link and gets a new one. */
export const resetInvite = callable.onCall(async (data, context) => {
  const uid = requireUid(context);
  const groupId = requireString(data?.groupId, "groupId");
  const db = getFirestore();
  const group = db.doc(`groups/${groupId}`);
  const code = await db.runTransaction(async (transaction) => {
    const groupData = (await transaction.get(group)).data();
    if (!groupData || groupData.createdBy !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the creator can reset the link.");
    }
    if (groupData.archivedAt) throw new functions.https.HttpsError("failed-precondition", "archived");
    if (typeof groupData.inviteCode === "string") transaction.delete(db.doc(`invites/${groupData.inviteCode}`));
    const fresh = newInviteCode();
    transaction.set(db.doc(`invites/${fresh}`), { groupId, createdAt: FieldValue.serverTimestamp() });
    transaction.update(group, { inviteCode: fresh });
    return fresh;
  });
  return { code };
});

async function groupForCode(code: string): Promise<FirebaseFirestore.DocumentReference> {
  const invite = (await getFirestore().doc(`invites/${code}`).get()).data();
  if (typeof invite?.groupId !== "string") throw new functions.https.HttpsError("not-found", "Unknown or reset link.");
  return getFirestore().doc(`groups/${invite.groupId}`);
}

/** What a non-member may see before joining: the name, picture and member count. */
export const previewInvite = callable.onCall(async (data, context) => {
  const uid = requireUid(context);
  const code = requireString(data?.code, "code");
  const group = await groupForCode(code);
  const groupData = (await group.get()).data();
  if (!groupData) throw new functions.https.HttpsError("not-found", "Unknown or reset link.");
  const memberIds: string[] = groupData.memberIds ?? [];
  return {
    groupId: group.id,
    name: groupData.name,
    image: groupData.image ?? null,
    memberCount: memberIds.length,
    isMember: memberIds.includes(uid),
    isArchived: Boolean(groupData.archivedAt),
  };
});

/**
 * Adds the caller to the squabble behind the code, copying their public profile and
 * payment details into their entry, as the app does for the creator. Joining again is a
 * no-op.
 */
export const joinGroup = callable.onCall(async (data, context) => {
  const uid = requireUid(context);
  const code = requireString(data?.code, "code");
  const db = getFirestore();
  const group = await groupForCode(code);
  await db.runTransaction(async (transaction) => {
    const [groupSnapshot, profileSnapshot, paymentSnapshot] = await Promise.all([
      transaction.get(group),
      transaction.get(db.doc(`users/${uid}`)),
      transaction.get(db.doc(`users/${uid}/private/payment`)),
    ]);
    const groupData = groupSnapshot.data();
    // A reset between the lookup and here: the old code no longer belongs to this group.
    if (!groupData || groupData.inviteCode !== code) {
      throw new functions.https.HttpsError("not-found", "Unknown or reset link.");
    }
    const memberIds: string[] = groupData.memberIds ?? [];
    if (memberIds.includes(uid)) return;
    if (groupData.archivedAt) throw new functions.https.HttpsError("failed-precondition", "archived");
    if (memberIds.length >= maxMembers) throw new functions.https.HttpsError("resource-exhausted", "full");
    const profile = profileSnapshot.data();
    if (!profile) throw new functions.https.HttpsError("failed-precondition", "no-profile");

    const entry: Record<string, unknown> = {
      displayName: profile.displayName,
      avatar: profile.avatar,
      payment: paymentSnapshot.data()?.methods ?? [],
      joinedAt: FieldValue.serverTimestamp(),
    };
    if (typeof profile.handle === "string") entry.handle = profile.handle;
    transaction.update(group, {
      memberIds: FieldValue.arrayUnion(uid),
      [`members.${uid}`]: entry,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { groupId: group.id };
});
