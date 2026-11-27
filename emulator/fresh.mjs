// Adds squabbles the phone has never seen to the running emulator, so their chats aren't in its
// cache yet: for trying first loads and paging on a slow network. Nothing is wiped, and every run
// makes new ones with new ids. Needs the seed's people (emulator/start.sh).
//   node emulator/fresh.mjs        three squabbles: 8, 130 and 300 messages
import { createRequire } from "node:module";
import { randomBytes } from "node:crypto";

const projectId = "demo-squabble";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

initializeApp({ projectId });
const db = getFirestore();

const minute = 60_000;
const now = Date.now();
const ago = (minutes) => Timestamp.fromMillis(now - minutes * minute);

// The members' entries are copied from their profiles, as the app does when someone joins.
async function entry(uid, joinedAt) {
  const [profile, payment] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`users/${uid}/private/payment`).get()]);
  if (!profile.exists) throw new Error(`No ${uid} in the emulator: run emulator/start.sh first.`);
  const { displayName, handle, avatar } = profile.data();
  return { displayName, handle, avatar, payment: payment.data()?.methods ?? [], joinedAt };
}

const lines = [
  "Did anyone keep the receipt?", "I paid for the taxi, that counts.", "It does not count.",
  "Who ordered the second bottle?", "Asking for a friend.", "The friend is you.", "Fine.",
  "Can we split it by who actually ate?", "Absolutely not.",
];
const reactions = ["😂", "🙄", "👍", "❤️"];

async function fresh({ name, artwork, background, members, count, minutesAgo }) {
  const id = `fresh-${randomBytes(4).toString("hex")}`;
  const group = db.doc(`groups/${id}`);
  const createdAt = ago(minutesAgo + count * 10 + 60);
  const entries = await Promise.all(members.map((uid, i) => entry(uid, Timestamp.fromMillis(createdAt.toMillis() + i * minute))));
  await group.set({
    name, currency: "EUR", image: { kind: "artwork", artwork, background },
    createdBy: members[0], createdAt, updatedAt: createdAt,
    memberIds: members,
    members: Object.fromEntries(members.map((uid, i) => [uid, entries[i]])),
  });

  // Oldest first, ten minutes apart, the newest `minutesAgo` before now.
  const writer = db.bulkWriter();
  let last;
  for (let i = 1; i <= count; i++) {
    const authorId = members[i % members.length];
    const text = `${i}. ${lines[i % lines.length]}`;
    const more = i % 11 === 0 ? { reactions: { [members[(i + 1) % members.length]]: reactions[i % reactions.length] } } : {};
    writer.set(group.collection("messages").doc(`m${i}`), {
      authorId, kind: "text", text, createdAt: ago(minutesAgo + (count - i) * 10), reactions: {}, ...more,
    });
    last = { kind: "message", by: authorId, id: `m${i}`, text };
  }
  await writer.close();
  await group.update({ lastActivity: last, updatedAt: ago(minutesAgo) });
  return `${name} (${count} messages, groups/${id})`;
}

const stamp = new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
const made = [
  await fresh({ name: `Fresh short ${stamp}`, artwork: "trio", background: "mint", members: ["emma", "anna", "bela"], count: 8, minutesAgo: 1 }),
  await fresh({ name: `Fresh long ${stamp}`, artwork: "suits", background: "sunrise", members: ["emma", "cili", "anna"], count: 130, minutesAgo: 2 }),
  await fresh({ name: `Fresh huge ${stamp}`, artwork: "trio", background: "teal", members: ["emma", "bela", "cili", "anna"], count: 300, minutesAgo: 3 }),
];
console.log(`Added, for Emma:\n  ${made.join("\n  ")}`);
