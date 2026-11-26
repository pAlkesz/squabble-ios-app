import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  addDoc, collection, deleteDoc, deleteField, doc, getDoc, getDocs, limit, orderBy, query,
  serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch,
} from "firebase/firestore";
import { after, before, beforeEach, describe, test } from "node:test";
import { artwork, avatar, entry, group, joinedAt, message, seed, startEnvironment } from "./helpers.mjs";

let environment, anna, bela, cili, guest;

before(async () => {
  environment = await startEnvironment();
  anna = environment.authenticatedContext("anna").firestore();
  bela = environment.authenticatedContext("bela").firestore();
  cili = environment.authenticatedContext("cili").firestore();
  guest = environment.unauthenticatedContext().firestore();
});
beforeEach(() => environment.clearFirestore());
after(() => environment.cleanup());

const url = "https://firebasestorage.googleapis.com:443/v0/x";
const long = "x".repeat(101);
/** Avatars that must be refused wherever one is stored (for anna). */
const badAvatars = {
  "no avatar": "bird",
  "unknown kind": { kind: "emoji" },
  "preset with extras": { kind: "preset", preset: "coral", extra: 1 },
  "unknown preset": { kind: "preset", preset: "neon" },
  "persona with extras": { ...avatar, extra: 1 },
  "persona id of the wrong shape": { ...avatar, persona: "../x" },
  "persona id that isn't text": { ...avatar, persona: 1 },
  "unknown persona colour": { ...avatar, color: "neon" },
  "photo with extras": { kind: "photo", path: "avatars/anna/a.jpg", url, extra: 1 },
  "photo path that isn't text": { kind: "photo", path: 1, url },
  "photo from another folder": { kind: "photo", path: "avatars/bela/a.jpg", url },
  "photo hosted elsewhere": { kind: "photo", path: "avatars/anna/a.jpg", url: "https://example.com/x" },
  "photo address that isn't text": { kind: "photo", path: "avatars/anna/a.jpg", url: 1 },
};

const profile = (handle, more = {}) => ({
  displayName: "Anna", handle, avatar, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...more,
});

function onboard(db, uid, handle, more) {
  const batch = writeBatch(db);
  batch.set(doc(db, `handles/${handle}`), { uid });
  batch.set(doc(db, `users/${uid}`), profile(handle, more));
  return batch.commit();
}

describe("profiles and handles", () => {
  test("onboarding claims a handle with the profile", () => assertSucceeds(onboard(anna, "anna", "anna_x")));
  test("not for someone else", () => assertFails(onboard(anna, "bela", "anna_x")));
  test("not with extra fields", () => assertFails(onboard(anna, "anna", "anna_x", { admin: true })));
  test("not with an invalid handle", () => assertFails(onboard(anna, "anna", "Anna!")));
  for (const [name, bad] of Object.entries(badAvatars)) {
    test(`not with: ${name}`, () => assertFails(onboard(anna, "anna", "anna_x", { avatar: bad })));
  }
  test("with each kind of avatar", async () => {
    await assertSucceeds(onboard(anna, "anna", "anna_x", { avatar: { kind: "preset", preset: "coral" } }));
    await assertSucceeds(updateDoc(doc(anna, "users/anna"), { avatar: { kind: "photo", path: "avatars/anna/a.jpg", url } }));
  });
  test("not with a bad name or handle field", async () => {
    await assertFails(onboard(anna, "anna", "anna_x", { displayName: long }));
    await assertFails(onboard(anna, "anna", "anna_x", { displayName: ["a"] }));
    await assertFails(onboard(anna, "anna", "anna_x", { handle: 1 }));
  });
  test("not with a malformed handle lock", async () => {
    const claim = (lock) => {
      const batch = writeBatch(anna);
      batch.set(doc(anna, "handles/anna_x"), lock);
      batch.set(doc(anna, "users/anna"), profile("anna_x"));
      return batch.commit();
    };
    await assertFails(claim({ uid: "anna", extra: 1 }));
    await assertFails(claim({ uid: "bela" }));
  });
  test("not claiming a handle for someone else", async () => {
    await seed(environment, { "users/anna": profile("anna_x") });
    await assertFails(setDoc(doc(anna, "handles/anna_x"), { uid: "bela" }));
  });

  test("a profile needs its handle, and a handle its profile", async () => {
    await assertFails(setDoc(doc(anna, "users/anna"), profile("anna_x")));
    await assertFails(setDoc(doc(anna, "handles/anna_x"), { uid: "anna" }));
  });

  test("a taken handle can't be taken over", async () => {
    await seed(environment, { "handles/anna_x": { uid: "anna" }, "users/anna": { ...profile("anna_x"), createdAt: joinedAt, updatedAt: joinedAt } });
    await assertFails(onboard(bela, "bela", "anna_x"));
    await assertFails(updateDoc(doc(anna, "handles/anna_x"), { uid: "bela" }));
    await assertFails(deleteDoc(doc(bela, "handles/anna_x")));
    await assertSucceeds(deleteDoc(doc(anna, "handles/anna_x")));
  });

  test("profiles are readable by anyone signed in, writable by their owner", async () => {
    await seed(environment, { "handles/anna_x": { uid: "anna" }, "users/anna": profile("anna_x") });
    await assertSucceeds(getDoc(doc(bela, "users/anna")));
    await assertFails(getDoc(doc(guest, "users/anna")));
    await assertSucceeds(updateDoc(doc(anna, "users/anna"), { displayName: "Anna B" }));
    await assertFails(updateDoc(doc(bela, "users/anna"), { displayName: "Hacked" }));
    await assertFails(updateDoc(doc(anna, "users/anna"), { displayName: "" }));
  });
});

describe("private documents", () => {
  test("payment details are the owner's alone", async () => {
    await assertSucceeds(setDoc(doc(anna, "users/anna/private/payment"), { methods: [] }));
    await assertSucceeds(getDoc(doc(anna, "users/anna/private/payment")));
    await assertFails(getDoc(doc(bela, "users/anna/private/payment")));
    await assertFails(setDoc(doc(bela, "users/anna/private/payment"), { methods: [] }));
  });
  test("at most five payment methods", () =>
    assertFails(setDoc(doc(anna, "users/anna/private/payment"), { methods: [1, 2, 3, 4, 5, 6] })));
  test("payment holds methods and nothing else", async () => {
    await assertFails(setDoc(doc(anna, "users/anna/private/payment"), { methods: [], extra: 1 }));
    await assertFails(setDoc(doc(anna, "users/anna/private/payment"), { methods: { a: 1 } }));
  });
  test("preferences hold a currency or nothing", async () => {
    const preferences = doc(anna, "users/anna/private/preferences");
    await assertSucceeds(setDoc(preferences, { homeCurrency: "HUF" }));
    await assertSucceeds(setDoc(preferences, {}));
    await assertFails(setDoc(preferences, { homeCurrency: "forint" }));
    await assertFails(setDoc(preferences, { homeCurrency: "HUF", extra: 1 }));
    await assertFails(setDoc(doc(anna, "users/anna/private/other"), {}));
  });
});

describe("squabbles: reading", () => {
  beforeEach(() => seed(environment, { "groups/g": group(), "invites/code": { groupId: "g" } }));

  test("members only", async () => {
    await assertSucceeds(getDoc(doc(bela, "groups/g")));
    await assertFails(getDoc(doc(cili, "groups/g")));
    await assertFails(getDoc(doc(guest, "groups/g")));
  });
  test("the home query works, listing everything doesn't", async () => {
    await assertSucceeds(getDocs(query(collection(anna, "groups"), where("memberIds", "array-contains", "anna"))));
    await assertFails(getDocs(query(collection(cili, "groups"), where("memberIds", "array-contains", "anna"))));
    await assertFails(getDocs(collection(anna, "groups")));
  });
  test("invites are for the server only", async () => {
    await assertFails(getDoc(doc(anna, "invites/code")));
    await assertFails(setDoc(doc(anna, "invites/mine"), { groupId: "g" }));
  });
});

describe("squabbles: creating", () => {
  const fresh = (more = {}) => ({
    ...group(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    memberIds: ["anna"],
    members: { anna: { ...entry("anna"), joinedAt: serverTimestamp() } },
    ...more,
  });
  const create = (more) => setDoc(doc(anna, "groups/new"), fresh(more));

  test("alone works", () => assertSucceeds(create()));
  test("as someone else", () => assertFails(create({ createdBy: "bela" })));
  test("without being in it", () => assertFails(create({ memberIds: ["bela"], members: { bela: entry("bela") } })));
  test("with an invite code", () => assertFails(create({ inviteCode: "mine-mine" })));
  test("with balances", () => assertFails(create({ balances: { anna: 100 } })));
  test("already archived", () => assertFails(create({ archivedAt: serverTimestamp() })));
  test("with an empty name", () => assertFails(create({ name: "" })));
  test("with a made-up currency shape", () => assertFails(create({ currency: "euro" })));
  test("backdated", () => assertFails(create({ createdAt: joinedAt })));
  test("with an emoji picture", () => assertFails(create({ image: { kind: "emoji", emoji: "x", color: "coral" } })));
  test("with an unknown background", () => assertFails(create({ image: { ...artwork, background: "neon" } })));
  test("with extra people, their copies included, works", () =>
    assertSucceeds(create({ memberIds: ["anna", "bela"], members: { ...fresh().members, bela: entry("bela") } })));
  test("with bad names and currencies", async () => {
    await assertFails(create({ name: long }));
    await assertFails(create({ name: ["Flat"] }));
    await assertFails(create({ currency: 1 }));
  });
  test("with activity in the past", () => assertFails(create({ updatedAt: joinedAt })));
  test("with a mismatched member list", async () => {
    const both = { ...fresh().members, bela: entry("bela") };
    await assertFails(create({ memberIds: ["bela", "anna"], members: both }));
    await assertFails(create({ memberIds: ["anna", "bela"] }));
    await assertFails(create({ members: both }));
    await assertFails(create({ memberIds: ["anna", "cili"], members: both }));
    await assertFails(create({ memberIds: ["anna", "anna"] }));
    await assertFails(create({ memberIds: { 0: "anna" } }));
    await assertFails(create({ members: ["anna"] }));
  });
  test("with a malformed entry of your own", () => assertFails(create({ members: { anna: { ...entry("anna"), deleted: true } } })));
  const photo = { kind: "photo", path: "groupImages/anna/a.jpg", url };
  test("with your own photo works", () => assertSucceeds(create({ image: photo })));
  for (const [name, image] of Object.entries({
    "drawing with extras": { ...artwork, extra: 1 },
    "drawing id of the wrong shape": { ...artwork, artwork: "../x" },
    "drawing id that isn't text": { ...artwork, artwork: 1 },
    "photo with extras": { ...photo, extra: 1 },
    "photo path that isn't text": { ...photo, path: 1 },
    "photo from another folder": { ...photo, path: "groupImages/bela/a.jpg" },
    "photo hosted elsewhere": { ...photo, url: "https://example.com/x" },
    "photo address that isn't text": { ...photo, url: 1 },
  })) {
    test(`with a ${name}`, () => assertFails(create({ image })));
  }
  test("with more than 50 members", () => {
    const ids = ["anna", ...Array.from({ length: 50 }, (_, i) => `u${i}`)];
    return assertFails(create({ memberIds: ids, members: Object.fromEntries(ids.map((id) => [id, entry("anna")])) }));
  });
});

describe("squabbles: updating", () => {
  beforeEach(() => seed(environment, { "groups/g": group(), "groups/old": group({ archivedAt: joinedAt }) }));
  const update = (db, fields, id = "g") => updateDoc(doc(db, `groups/${id}`), fields);

  test("your own entry", () => assertSucceeds(update(bela, { "members.bela.displayName": "Béla" })));
  test("not someone else's", () => assertFails(update(bela, { "members.anna.displayName": "Hacked" })));
  test("not your join date", () => assertFails(update(bela, { "members.bela.joinedAt": Timestamp.now() })));
  test("not the server's fields on your entry", () => assertFails(update(bela, { "members.bela.deleted": true })));
  test("not as a non-member", () => assertFails(update(cili, { "members.cili": entry("cili") })));
  test("not once you've left", async () => {
    await seed(environment, { "groups/left": group({ memberIds: ["bela"] }) });
    await assertFails(update(anna, { "members.anna.displayName": "Back" }, "left"));
  });
  for (const [name, fields] of Object.entries({
    "an empty name": { displayName: "" },
    "a long name": { displayName: long },
    "a name that isn't text": { displayName: ["a"] },
    "a malformed handle": { handle: "Anna!" },
    "payment that isn't a list": { payment: { a: 1 } },
    "six payment methods": { payment: [1, 2, 3, 4, 5, 6] },
    ...Object.fromEntries(Object.entries(badAvatars).map(([name, bad]) => [name, { avatar: bad }])),
  })) {
    test(`not your entry with: ${name}`, () =>
      assertFails(update(anna, Object.fromEntries(Object.entries(fields).map(([key, value]) => [`members.anna.${key}`, value])))));
  }
  test("not letting yourself in", () => assertFails(update(cili, { memberIds: ["anna", "bela", "cili"] })));
  test("not adding people", () => assertFails(update(anna, { memberIds: ["anna", "bela", "cili"] })));
  for (const fields of [{ createdBy: "bela" }, { inviteCode: "mine-mine" }, { balances: { bela: 1 } }, { involvedIds: ["bela"] }, { chapter: 2 }, { currency: "USD" }, { name: "New" }]) {
    test(`not ${Object.keys(fields)[0]}`, () => assertFails(update(bela, fields)));
  }
  test("not deleting", () => assertFails(deleteDoc(doc(anna, "groups/g"))));

  test("activity: to now, by members", async () => {
    await assertSucceeds(update(bela, { updatedAt: serverTimestamp() }));
    await assertFails(update(cili, { updatedAt: serverTimestamp() }));
    await assertFails(update(bela, { updatedAt: Timestamp.fromMillis(Date.now() + 1e9) }));
    await assertFails(update(bela, { updatedAt: serverTimestamp(), name: "New" }));
  });
  test("last activity: your own, of a known kind", async () => {
    const activity = (more = {}) => ({ kind: "message", by: "bela", id: "m", text: "Hi", ...more });
    await assertSucceeds(update(bela, { updatedAt: serverTimestamp(), lastActivity: activity() }));
    await assertSucceeds(update(bela, { lastActivity: { kind: "messageDeleted", by: "bela", id: "m" } }));
    await assertSucceeds(update(bela, { lastActivity: { kind: "billDeleted", by: "bela", id: "b", text: "Dinner" } }));
    await assertFails(update(bela, { lastActivity: activity({ by: "anna" }) }));
    await assertFails(update(cili, { lastActivity: { ...activity(), by: "cili" } }));
    await assertFails(update(bela, { lastActivity: activity({ kind: "payday" }) }));
    await assertFails(update(bela, { lastActivity: activity({ text: "x".repeat(401) }) }));
    await assertFails(update(bela, { lastActivity: activity({ link: "https://example.com" }) }));
    await assertFails(update(bela, { lastActivity: { kind: "message", by: "bela" } }));
    await assertFails(update(bela, { lastActivity: activity(), updatedAt: joinedAt }));
  });
  test("nothing once archived", async () => {
    await assertFails(update(bela, { "members.bela.displayName": "Béla" }, "old"));
    await assertFails(update(bela, { updatedAt: serverTimestamp() }, "old"));
  });
});

describe("chat", () => {
  beforeEach(() => seed(environment, {
    "groups/g": group(),
    "groups/old": group({ archivedAt: joinedAt }),
    "groups/g/messages/m": message("anna"),
    "groups/g/messages/gone": { authorId: "anna", kind: "text", createdAt: joinedAt, deletedAt: joinedAt, reactions: {} },
    "groups/old/messages/m": message("anna"),
  }));
  const post = (db, more = {}, id = "g") =>
    setDoc(doc(db, `groups/${id}/messages/new`), message("bela", { createdAt: serverTimestamp(), ...more }));
  const edit = (db, fields, path = "g/messages/m") => updateDoc(doc(db, `groups/${path}`), fields);

  test("sending as the app does, with the activity bump", () => {
    const batch = writeBatch(bela);
    batch.set(doc(bela, "groups/g/messages/new"), message("bela", { createdAt: serverTimestamp() }));
    batch.update(doc(bela, "groups/g"), { updatedAt: serverTimestamp(), lastActivity: { kind: "message", by: "bela", id: "new", text: "Hi" } });
    return assertSucceeds(batch.commit());
  });
  test("replying", () => assertSucceeds(post(bela, { replyTo: { id: "m", authorId: "anna", preview: "Hi" } })));
  test("as someone else", () => assertFails(post(bela, { authorId: "anna" })));
  test("from outside", () => assertFails(post(cili, { authorId: "cili" })));
  test("empty or huge", async () => {
    await assertFails(post(bela, { text: "" }));
    await assertFails(post(bela, { text: "x".repeat(4001) }));
  });
  test("backdated", () => assertFails(post(bela, { createdAt: joinedAt })));
  test("with reactions already on it", () => assertFails(post(bela, { reactions: { anna: "👍" } })));
  test("with a huge preview", () => assertFails(post(bela, { replyTo: { id: "m", authorId: "anna", preview: "x".repeat(401) } })));
  test("with the wrong shape", async () => {
    const replyTo = { id: "m", authorId: "anna", preview: "Hi" };
    await assertFails(post(bela, { extra: 1 }));
    await assertFails(post(bela, { kind: "system" }));
    await assertFails(post(bela, { text: ["Hi"] }));
    await assertFails(post(bela, { replyTo: "m" }));
    await assertFails(post(bela, { replyTo: { ...replyTo, extra: 1 } }));
    await assertFails(post(bela, { replyTo: { ...replyTo, preview: ["Hi"] } }));
  });
  test("in an archived squabble", () => assertFails(post(bela, {}, "old")));

  test("the page's query, members only", async () => {
    const latest = (db) => getDocs(query(collection(db, "groups/g/messages"), orderBy("createdAt", "desc"), limit(50)));
    await assertSucceeds(latest(bela));
    await assertFails(latest(cili));
  });
  test("archived chats stay readable", () => assertSucceeds(getDoc(doc(bela, "groups/old/messages/m"))));

  test("your own reaction, on and off", async () => {
    await assertSucceeds(edit(bela, { "reactions.bela": "👍" }));
    await assertSucceeds(edit(bela, { "reactions.bela": deleteField() }));
  });
  test("not someone else's reaction", () => assertFails(edit(bela, { "reactions.anna": "👍" })));
  test("not a long reaction", () => assertFails(edit(bela, { "reactions.bela": "x".repeat(17) })));
  test("not from outside", () => assertFails(edit(cili, { "reactions.cili": "👍" })));
  test("not once archived", () => assertFails(edit(bela, { "reactions.bela": "👍" }, "old/messages/m")));

  test("deleting blanks your own message, once", async () => {
    await assertFails(edit(bela, { text: deleteField(), deletedAt: serverTimestamp() }));
    await assertFails(edit(anna, { deletedAt: serverTimestamp() }));
    await assertSucceeds(edit(anna, { text: deleteField(), deletedAt: serverTimestamp() }));
    await assertFails(edit(anna, { deletedAt: serverTimestamp() }, "g/messages/gone"));
  });
  test("deleting can't change anything else", () =>
    assertFails(edit(anna, { text: deleteField(), deletedAt: serverTimestamp(), authorId: "bela" })));
  test("no editing or hard deleting", async () => {
    await assertFails(edit(anna, { text: "Changed" }));
    await assertFails(deleteDoc(doc(anna, "groups/g/messages/m")));
  });

  const report = (db, uid, more = {}) => addDoc(collection(db, "reports"), {
    groupId: "g", messageId: "m", authorId: "anna", text: "Hi", reportedBy: uid, createdAt: serverTimestamp(), ...more,
  });
  test("reporting is for members, as themselves, and never read back", async () => {
    await assertSucceeds(report(bela, "bela"));
    await assertFails(report(bela, "anna"));
    await assertFails(report(cili, "cili"));
    await assertFails(report(bela, "bela", { extra: 1 }));
    await assertFails(report(bela, "bela", { createdAt: joinedAt }));
    await assertFails(getDocs(collection(bela, "reports")));
  });
});

describe("bills", () => {
  const bill = (more = {}) => ({
    title: "Dinner", date: "2026-11-25", currency: "EUR", totalMinor: 1000, paidBy: "anna", split: "equally",
    shares: { anna: 500, bela: 500 }, createdBy: "bela", createdAt: joinedAt, updatedBy: "bela", updatedAt: joinedAt, ...more,
  });
  beforeEach(() => seed(environment, {
    "groups/g": group(),
    "groups/old": group({ archivedAt: joinedAt }),
    "groups/g/bills/b": bill(),
    "groups/g/bills/gone": bill({ deletedAt: joinedAt }),
    "groups/old/bills/b": bill(),
  }));
  const create = (more = {}, db = bela, id = "g") =>
    setDoc(doc(db, `groups/${id}/bills/new`), bill({ createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...more }));
  const edit = (db, fields, path = "g/bills/b") =>
    updateDoc(doc(db, `groups/${path.split("/")[0]}/bills/${path.split("/")[2]}`), { updatedAt: serverTimestamp(), ...fields });

  test("adding as the app does, with the activity bump", () => {
    const batch = writeBatch(bela);
    batch.set(doc(bela, "groups/g/bills/new"), bill({ createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    batch.update(doc(bela, "groups/g"), { updatedAt: serverTimestamp(), lastActivity: { kind: "billAdded", by: "bela", id: "new", text: "Dinner" } });
    return assertSucceeds(batch.commit());
  });
  test("split by exact amounts", () => assertSucceeds(create({ split: "exactly" })));
  test("reading is for members", async () => {
    const latest = (db) => getDocs(query(collection(db, "groups/g/bills"), orderBy("createdAt", "desc"), limit(50)));
    await assertSucceeds(latest(anna));
    await assertFails(latest(cili));
    await assertSucceeds(getDoc(doc(anna, "groups/old/bills/b")));
  });
  for (const [name, more] of Object.entries({
    "extra fields": { extra: 1 },
    "the server's fields": { frozen: {} },
    "an empty title": { title: "" },
    "a long title": { title: "x".repeat(121) },
    "a title that isn't text": { title: ["x"] },
    "a date of the wrong shape": { date: "25 Nov" },
    "another currency": { currency: "USD" },
    "a zero total": { totalMinor: 0 },
    "a fractional total": { totalMinor: 1.5 },
    "a huge total": { totalMinor: 1000000000001 },
    "a stranger paying": { paidBy: "cili" },
    "an unknown split": { split: "vibes" },
    "no shares": { shares: {} },
    "shares that aren't a map": { shares: ["anna"] },
    "a stranger's share": { shares: { anna: 500, cili: 500 } },
    "someone else as its creator": { createdBy: "anna" },
    "someone else as its editor": { updatedBy: "anna" },
    "a creation in the past": { createdAt: joinedAt },
    "an edit in the past": { updatedAt: joinedAt },
  })) {
    test(`not with ${name}`, () => assertFails(create(more)));
  }
  test("not from outside", () => assertFails(create({ createdBy: "cili", updatedBy: "cili" }, cili)));
  test("not once archived", async () => {
    await assertFails(create({}, bela, "old"));
    await assertFails(edit(anna, { title: "New", updatedBy: "anna" }, "old/bills/b"));
  });

  test("any member edits, as themselves", async () => {
    await assertSucceeds(edit(anna, { title: "Lunch", totalMinor: 800, shares: { anna: 400, bela: 400 }, updatedBy: "anna" }));
    await assertFails(edit(anna, { title: "Lunch", updatedBy: "bela" }));
    await assertFails(edit(cili, { title: "Lunch", updatedBy: "cili" }));
    await assertFails(edit(anna, { totalMinor: 0, updatedBy: "anna" }));
  });
  test("who added it and when never change", async () => {
    await assertFails(edit(anna, { createdBy: "anna", updatedBy: "anna" }));
    await assertFails(edit(anna, { createdAt: serverTimestamp(), updatedBy: "anna" }));
  });
  test("any member deletes, leaving a trace", async () => {
    await assertFails(edit(anna, { deletedAt: serverTimestamp(), updatedBy: "bela" }));
    await assertFails(edit(anna, { deletedAt: joinedAt, updatedBy: "anna" }));
    await assertFails(edit(anna, { deletedAt: serverTimestamp(), updatedBy: "anna", updatedAt: joinedAt }));
    await assertFails(edit(anna, { deletedAt: serverTimestamp(), updatedBy: "anna", title: "Gone" }));
    await assertSucceeds(edit(anna, { deletedAt: serverTimestamp(), updatedBy: "anna" }));
    await assertFails(deleteDoc(doc(anna, "groups/g/bills/b")));
  });
  test("a deleted bill stays as it is", () => assertFails(edit(anna, { deletedAt: deleteField(), updatedBy: "anna" }, "g/bills/gone")));
  test("someone who left can still be on an old bill", async () => {
    await seed(environment, { "groups/g": group({ memberIds: ["anna"] }) });
    await assertSucceeds(edit(anna, { title: "Lunch", updatedBy: "anna" }));
    await assertFails(edit(bela, { title: "Lunch", updatedBy: "bela" }));
  });
});

test("exchange rates are for reading, by members of the club", async () => {
  await seed(environment, { "rates/latest": { base: "EUR" } });
  await assertSucceeds(getDoc(doc(anna, "rates/latest")));
  await assertFails(getDoc(doc(guest, "rates/latest")));
  await assertFails(getDocs(collection(anna, "rates")));
  await assertFails(setDoc(doc(anna, "rates/latest"), { base: "USD" }));
  await assertFails(deleteDoc(doc(anna, "rates/latest")));
});

test("anything unlisted is closed", async () => {
  await assertFails(getDoc(doc(anna, "rates/2026-11-25")));
  await assertFails(setDoc(doc(anna, "groups/g/settlements/s"), { amountMinor: 1 }));
});
