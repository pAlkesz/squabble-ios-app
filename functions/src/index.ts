import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
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
 * Covers (see CLAUDE.md, "Firestore data model"): users/{uid} and its private documents,
 * the user's handles/{handle} lock, and avatars/{uid}/ in Storage. Anything new stored per
 * user belongs here too.
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

    await getStorage().bucket().deleteFiles({ prefix: `avatars/${uid}/` });

    functions.logger.info("Deleted user data", { uid, handles: handles.size });
  });
