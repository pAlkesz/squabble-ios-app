// Wipes the local Firestore emulator and fills it with fake people and squabbles.
// Run it again any time to reset. It can only ever talk to this machine: the hosts are set
// here, before the SDK loads, and the project doesn't exist online.
import { createRequire } from "node:module";

const projectId = "demo-squabble";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

// The same people as `EmulatorPerson` in the app. Password for all of them: local emulator
// only, it opens nothing anywhere else.
const password = "squabble-local";
const bank = (id, holderName) => ({ id, kind: "bankAccount", iban: "DE89370400440532013000", holderName });
const people = {
  anna: { name: "Anna Example", persona: "bigSpender", color: "coral", payment: [bank("a1", "Anna Example")] },
  bela: { name: "Béla Example", persona: "afterPayday", color: "lagoon", payment: [] },
  cili: { name: "Cili Example", persona: "artExpert", color: "plum", payment: [{ id: "c1", kind: "link", provider: "revolut", username: "ciliexample" }] },
  dora: { name: "Dóra Example", persona: "debtSpiral", color: "olive", payment: [] },
};

const minute = 60_000;
const now = Date.now();
const ago = (minutes) => Timestamp.fromMillis(now - minutes * minute);

const profile = (id) => ({
  displayName: people[id].name,
  handle: `${id}_example`,
  avatar: { kind: "persona", persona: people[id].persona, color: people[id].color },
});

const wiped = await fetch(
  `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
  { method: "DELETE" },
);
if (!wiped.ok) throw new Error(`Couldn't wipe the emulator: ${wiped.status}`);

for (const id of Object.keys(people)) {
  const account = { email: `${id}@example.com`, password, displayName: people[id].name };
  try {
    await auth.updateUser(id, account);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({ uid: id, ...account });
  }
  const { handle } = profile(id);
  await db.doc(`users/${id}`).set({ ...profile(id), createdAt: ago(60 * 24 * 90), updatedAt: ago(60 * 24 * 90) });
  await db.doc(`users/${id}/private/payment`).set({ methods: people[id].payment });
  await db.doc(`handles/${handle}`).set({ uid: id });
}

async function squabble(id, { name, currency, artwork, background, members, deleted = [], createdAt, updatedAt, inviteCode }) {
  const entry = (uid, index) => [uid, { ...profile(uid), payment: people[uid].payment, joinedAt: Timestamp.fromMillis(createdAt.toMillis() + index * minute) }];
  await db.doc(`groups/${id}`).set({
    name,
    currency,
    image: { kind: "artwork", artwork, background },
    createdBy: members[0],
    createdAt,
    updatedAt,
    memberIds: members,
    members: {
      ...Object.fromEntries(members.map(entry)),
      ...Object.fromEntries(deleted.map((uid) => [uid, { deleted: true }])),
    },
    inviteCode,
  });
  await db.doc(`invites/${inviteCode}`).set({ groupId: id, createdAt });
}

const message = (groupId, id, authorId, text, createdAt, more = {}) =>
  db.doc(`groups/${groupId}/messages/${id}`).set({ authorId, kind: "text", text, createdAt, reactions: {}, ...more });

// Brand new: nothing in it but the two of them.
await squabble("flat", {
  name: "Flat", currency: "HUF", artwork: "suits", background: "peach",
  members: ["anna", "bela"], createdAt: ago(30), updatedAt: ago(29), inviteCode: "local-flat",
});

// A busy chat: 130 messages, so three pages, over three days.
await squabble("vienna", {
  name: "Vienna weekend", currency: "EUR", artwork: "trio", background: "sky",
  members: ["anna", "bela", "cili"], createdAt: ago(60 * 24 * 4), updatedAt: ago(5), inviteCode: "local-vienna",
});
const lines = ["Who had the lobster?", "Not me.", "It was definitely you.", "I had a salad.", "A salad with lobster.", "Let's move on.", "Never."];
const authors = ["anna", "bela", "cili", "cili"];
for (let i = 1; i <= 130; i++) {
  const author = authors[i % authors.length];
  const more = {};
  if (i % 17 === 0) more.reactions = { anna: "😂", bela: "🙄" };
  if (i % 23 === 0) more.replyTo = { id: `m${i - 1}`, authorId: authors[(i - 1) % authors.length], preview: `${i - 1}. ${lines[(i - 1) % lines.length]}` };
  await message("vienna", `m${i}`, author, `${i}. ${lines[i % lines.length]}`, ago(5 + (130 - i) * 30), more);
}

// Someone who deleted their account.
await squabble("ghost", {
  name: "Ghosted dinner", currency: "EUR", artwork: "trio", background: "dusk",
  members: ["cili", "anna"], deleted: ["gone"], createdAt: ago(60 * 24 * 40), updatedAt: ago(60 * 24 * 10), inviteCode: "local-ghost",
});
await db.doc("groups/ghost/messages/g1").set({ authorId: "gone", kind: "text", createdAt: ago(60 * 24 * 11), deletedAt: ago(60 * 24 * 10), reactions: {} });
await message("ghost", "g2", "anna", "So who's paying for the dessert now?", ago(60 * 24 * 10));

// Bills; the balances come from the `updateBalances` function, as they would live.
const bill = (groupId, id, currency, title, totalMinor, paidBy, shares, createdAt) =>
  db.doc(`groups/${groupId}/bills/${id}`).set({
    title, date: createdAt.toDate().toISOString().slice(0, 10), currency, totalMinor, paidBy, split: "equally", shares,
    createdBy: paidBy, createdAt, updatedBy: paidBy, updatedAt: createdAt,
  });
await bill("vienna", "hotel", "EUR", "Hotel", 48000, "anna", { anna: 16000, bela: 16000, cili: 16000 }, ago(60 * 24 * 2));
await bill("vienna", "lobster", "EUR", "The lobster", 10000, "cili", { anna: 3334, bela: 3333, cili: 3333 }, ago(60 * 5));
await bill("vienna", "coffee", "EUR", "Coffee", 740, "bela", { anna: 370, bela: 370 }, ago(3));
// Cili is deep in debt: someone has to be.
await bill("ghost", "wine", "EUR", "Wine, all of it", 92000, "anna", { cili: 92000 }, ago(60 * 24 * 10 + 5));

// Dóra is in nothing yet, for joining.
console.log(`Seeded ${Object.keys(people).length} people and 3 squabbles.`);
