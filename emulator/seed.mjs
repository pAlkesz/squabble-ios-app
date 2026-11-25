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
  emma: { name: "Emma Example", persona: "tricklingIn", color: "rose", payment: [bank("e1", "Emma Example")] },
  anna: { name: "Anna Example", persona: "bigSpender", color: "coral", payment: [bank("a1", "Anna Example")] },
  bela: { name: "Béla Example", persona: "afterPayday", color: "lagoon", payment: [] },
  cili: { name: "Cili Example", persona: "artExpert", color: "plum", payment: [{ id: "c1", kind: "link", provider: "revolut", username: "ciliexample" }] },
  dora: { name: "Dóra Example", persona: "debtSpiral", color: "olive", payment: [] },
};

// Only there to fill the big squabble: nobody signs in as them.
const crowdNames = [
  "Árvíztűrő Tükörfúrógép-Nagyszentmiklósi", "Bo", "Maximiliana Featherstonehaugh-Cholmondeley", "Dávid", "Eszter 🎉",
  "Ferenc", "Gizi", "Hanna Bartholomew", "Imre", "Judit", "Kata", "Levente", "Márton", "Nóra", "Olivér", "Panni", "Réka",
];
const personas = ["bigSpender", "afterPayday", "methodActor", "worthWhatYouHave", "artExpert", "tooMuchForYou", "chunkBiter", "companyFunded", "debtSpiral", "tricklingIn"];
const colors = ["meadow", "lagoon", "coral", "mustard", "plum", "tangerine", "rose", "indigo", "olive", "slate", "cocoa"];
const crowd = crowdNames.map((_, i) => `crowd${i + 1}`);
crowd.forEach((id, i) => {
  people[id] = { name: crowdNames[i], persona: personas[i % personas.length], color: colors[i % colors.length], payment: [] };
});

const minute = 60_000;
// In minutes, for `ago`.
const hour = 60;
const day = 24 * hour;
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

for (const id of Object.keys(people).filter((id) => !crowd.includes(id))) {
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

async function squabble(id, { name, currency, artwork, background, members, deleted = [], createdAt, updatedAt, archivedAt, inviteCode = `local-${id}` }) {
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
    ...(archivedAt && { archivedAt }),
  });
  await db.doc(`invites/${inviteCode}`).set({ groupId: id, createdAt });
}

const message = (groupId, id, authorId, text, createdAt, more = {}) =>
  db.doc(`groups/${groupId}/messages/${id}`).set({ authorId, kind: "text", text, createdAt, reactions: {}, ...more });

// Brand new: nothing in it but the three of them.
await squabble("flat", {
  name: "Flat", currency: "HUF", artwork: "suits", background: "peach",
  members: ["anna", "bela", "emma"], createdAt: ago(30), updatedAt: ago(29),
});

// A busy chat: 130 messages, so three pages, over three days.
await squabble("vienna", {
  name: "Vienna weekend", currency: "EUR", artwork: "trio", background: "sky",
  members: ["anna", "bela", "cili", "emma"], createdAt: ago(60 * 24 * 4), updatedAt: ago(5),
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
  members: ["cili", "anna", "emma"], deleted: ["gone"], createdAt: ago(60 * 24 * 40), updatedAt: ago(60 * 24 * 10),
});
await db.doc("groups/ghost/messages/g1").set({ authorId: "gone", kind: "text", createdAt: ago(60 * 24 * 11), deletedAt: ago(60 * 24 * 10), reactions: {} });
await message("ghost", "g2", "anna", "So who's paying for the dessert now?", ago(60 * 24 * 10));

// Bills; the balances come from the `updateBalances` function, as they would live.
const bill = (groupId, id, currency, title, paidBy, shares, createdAt, more = {}) =>
  db.doc(`groups/${groupId}/bills/${id}`).set({
    title, date: createdAt.toDate().toISOString().slice(0, 10), currency,
    totalMinor: Object.values(shares).reduce((sum, share) => sum + share, 0),
    paidBy, split: "equally", shares, createdBy: paidBy, createdAt, updatedBy: paidBy, updatedAt: createdAt, ...more,
  });
const exactly = { split: "exactly" };

await bill("vienna", "hotel", "EUR", "Hotel", "anna", { anna: 12000, bela: 12000, cili: 12000, emma: 12000 }, ago(2 * day));
await bill("vienna", "opera", "EUR", "Opera, standing", "emma", { anna: 3000, bela: 3000, cili: 3000, emma: 3000 }, ago(1 * day));
await bill("vienna", "lobster", "EUR", "The lobster", "cili", { anna: 3334, bela: 3333, cili: 3333 }, ago(5 * hour));
await bill("vienna", "coffee", "EUR", "Coffee", "bela", { anna: 370, bela: 370 }, ago(3));
// Cili is deep in debt: someone has to be. The deleted member still owes their share.
await bill("ghost", "wine", "EUR", "Wine, all of it", "anna", { cili: 92000 }, ago(10 * day + 5), exactly);
await bill("ghost", "dinner", "EUR", "Dinner", "emma", { cili: 2500, emma: 2500, gone: 2500 }, ago(12 * day));

// Made up but plausible. The scheduled function doesn't run here.
await db.doc("rates/latest").set({ base: "EUR", date: new Date(now).toISOString().slice(0, 10), rates: { HUF: "380", USD: "1.1", GBP: "0.85", CZK: "25", PLN: "4.3" } });

// The rest exist for Emma: one squabble per state a screen can be in.
await squabble("solo", {
  name: "Just me", currency: "EUR", artwork: "suits", background: "sand",
  members: ["emma"], createdAt: ago(10), updatedAt: ago(10),
});

await squabble("square", {
  name: "All square", currency: "EUR", artwork: "trio", background: "mint",
  members: ["emma", "bela"], createdAt: ago(20 * day), updatedAt: ago(1 * day),
});
await bill("square", "cinema", "EUR", "Cinema", "emma", { bela: 1500, emma: 1500 }, ago(3 * day));
await bill("square", "popcorn", "EUR", "Suspiciously expensive popcorn", "bela", { bela: 1500, emma: 1500 }, ago(2 * day));
await message("square", "s1", "bela", "Friendship restored.", ago(1 * day), { reactions: { emma: "❤️" } });

await squabble("red", {
  name: "Ski trip", currency: "EUR", artwork: "trio", background: "storm",
  members: ["anna", "bela", "emma"], createdAt: ago(12 * day), updatedAt: ago(2 * hour),
});
await bill("red", "chalet", "EUR", "Chalet", "anna", { anna: 30000, bela: 30000, emma: 30000 }, ago(5 * day));
await bill("red", "passes", "EUR", "Ski passes", "bela", { anna: 11450, bela: 11450, emma: 11450 }, ago(4 * day));
await message("red", "r1", "anna", "Emma, the mountain sends its regards. So does my bank.", ago(2 * hour));

await squabble("small", {
  name: "Coffee run", currency: "EUR", artwork: "suits", background: "peach",
  members: ["cili", "emma"], createdAt: ago(6 * day), updatedAt: ago(6 * hour),
});
await bill("small", "flat-white", "EUR", "Flat white", "cili", { emma: 190 }, ago(6 * hour), exactly);

await squabble("green", {
  name: "Birthday bash", currency: "EUR", artwork: "trio", background: "bubblegum",
  members: ["emma", "anna", "bela", "cili"], createdAt: ago(9 * day), updatedAt: ago(8 * hour),
});
await bill("green", "venue", "EUR", "Venue", "emma", { anna: 8500, bela: 8500, cili: 8500, emma: 8500 }, ago(3 * day));
await bill("green", "cake", "EUR", "Cake the size of a car", "emma", { anna: 3334, bela: 3333, cili: 3333 }, ago(3 * day - 30), exactly);
await message("green", "b1", "bela", "Best party ever. Bill? What bill?", ago(8 * hour), { reactions: { emma: "🙄" } });

await squabble("forint", {
  name: "Forint flat", currency: "HUF", artwork: "suits", background: "teal",
  members: ["bela", "emma", "dora"], createdAt: ago(60 * day), updatedAt: ago(4 * day),
});
await bill("forint", "rent", "HUF", "Rent", "bela", { bela: 120000, emma: 120000, dora: 120000 }, ago(5 * day));
await bill("forint", "power", "HUF", "Electricity", "emma", { bela: 9167, emma: 9166, dora: 9167 }, ago(4 * day));

await squabble("big", {
  name: "The whole extended family reunion, 2026", currency: "EUR", artwork: "trio", background: "lilac",
  members: ["emma", "anna", "bela", ...crowd], createdAt: ago(14 * day), updatedAt: ago(3 * hour),
});
const everyone = ["emma", "anna", "bela", ...crowd];
await bill("big", "barbecue", "EUR", "Barbecue for the entire family, including the cousins nobody invited", "anna", Object.fromEntries(everyone.map((uid) => [uid, 1250])), ago(2 * day));
await bill("big", "tent", "EUR", "Tent", "crowd1", Object.fromEntries(everyone.map((uid) => [uid, 900])), ago(2 * day - 20));
await message("big", "f1", "crowd3", "I only had a salad, and I have been waiting two days for somebody to notice that I was charged for the barbecue like everyone else, so I am now saying it here, in writing, in front of the whole family.", ago(4 * hour), { reactions: { anna: "😂", bela: "😂", crowd1: "🙄", crowd4: "❤️" } });
await message("big", "f2", "emma", "Noted.", ago(3 * hour));

await squabble("chat", {
  name: "All talk", currency: "EUR", artwork: "suits", background: "sky",
  members: ["dora", "emma"], createdAt: ago(8 * day), updatedAt: ago(3 * day),
});
await message("chat", "t1", "dora", "Should we plan the trip?", ago(3 * day + 30));
await message("chat", "t2", "emma", "Yes!", ago(3 * day + 20));
await message("chat", "t3", "dora", "So who's booking?", ago(3 * day));

await squabble("edits", {
  name: "Second thoughts", currency: "EUR", artwork: "trio", background: "sunrise",
  members: ["emma", "cili"], createdAt: ago(15 * day), updatedAt: ago(5 * day),
});
await bill("edits", "taxi", "EUR", "Taxi (corrected twice)", "emma", { cili: 1800, emma: 600 }, ago(6 * day), { ...exactly, updatedBy: "cili", updatedAt: ago(5 * day) });
await bill("edits", "kebab", "EUR", "Kebab", "cili", { cili: 700, emma: 700 }, ago(6 * day - 30), { updatedBy: "emma", updatedAt: ago(5 * day), deletedAt: ago(5 * day) });
await message("edits", "e1", "cili", "…", ago(5 * day + 10));
await db.doc("groups/edits/messages/e2").set({ authorId: "emma", kind: "text", createdAt: ago(5 * day + 5), deletedAt: ago(5 * day), reactions: {} });

await squabble("archived", {
  name: "Old festival", currency: "EUR", artwork: "suits", background: "storm",
  members: ["bela", "emma"], createdAt: ago(200 * day), updatedAt: ago(120 * day), archivedAt: ago(120 * day),
});
await bill("archived", "camping", "EUR", "Camping", "bela", { bela: 2200, emma: 2200 }, ago(125 * day));

console.log(`Seeded ${Object.keys(people).length} people and 13 squabbles. Sign in as Emma to see them all.`);
