import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { readFile } from "node:fs/promises";
import { doc, setDoc, setLogLevel, Timestamp } from "firebase/firestore";

// Every refusal the tests expect would be logged as an error.
setLogLevel("silent");

const rules = (name) => readFile(new URL(`../../${name}`, import.meta.url), "utf8");

export async function startEnvironment() {
  return initializeTestEnvironment({
    projectId: "demo-squabble",
    firestore: { host: "127.0.0.1", port: 8080, rules: await rules("firestore.rules") },
    storage: { host: "127.0.0.1", port: 9199, rules: await rules("storage.rules") },
  });
}

export const avatar = { kind: "persona", persona: "bigSpender", color: "coral" };
export const artwork = { kind: "artwork", artwork: "trio", background: "sky" };
export const joinedAt = Timestamp.fromMillis(1_000_000);
export const entry = (name) => ({ displayName: name, handle: name, avatar, payment: [] });

/** A squabble of anna (the creator) and bela; cili isn't in it. */
export const group = (more = {}) => ({
  name: "Flat",
  currency: "EUR",
  image: artwork,
  createdBy: "anna",
  createdAt: joinedAt,
  updatedAt: joinedAt,
  memberIds: ["anna", "bela"],
  members: { anna: { ...entry("anna"), joinedAt }, bela: { ...entry("bela"), joinedAt } },
  ...more,
});

export const message = (authorId, more = {}) => ({
  authorId, kind: "text", text: "Hi", createdAt: joinedAt, reactions: {}, ...more,
});

/** Writes past the rules. */
export async function seed(environment, documents) {
  await environment.withSecurityRulesDisabled(async (context) => {
    for (const [path, data] of Object.entries(documents)) {
      await setDoc(doc(context.firestore(), path), data);
    }
  });
}
