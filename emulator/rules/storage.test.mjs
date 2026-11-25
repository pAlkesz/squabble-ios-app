import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";
import { after, before, beforeEach, describe, test } from "node:test";
import { startEnvironment } from "./helpers.mjs";

let environment, anna, bela, guest;
const jpeg = { contentType: "image/jpeg" };
const small = new Uint8Array(10);

before(async () => {
  environment = await startEnvironment();
  anna = environment.authenticatedContext("anna").storage();
  bela = environment.authenticatedContext("bela").storage();
  guest = environment.unauthenticatedContext().storage();
});
beforeEach(() => environment.clearStorage());
after(() => environment.cleanup());

for (const folder of ["avatars", "groupImages"]) {
  describe(folder, () => {
    const path = `${folder}/anna/a.jpg`;

    test("the owner uploads, others don't", async () => {
      await assertSucceeds(uploadBytes(ref(anna, path), small, jpeg));
      await assertFails(uploadBytes(ref(bela, path), small, jpeg));
      await assertFails(uploadBytes(ref(guest, path), small, jpeg));
    });
    test("small JPEGs only", async () => {
      await assertFails(uploadBytes(ref(anna, path), new Uint8Array(1024 * 1024), jpeg));
      await assertFails(uploadBytes(ref(anna, path), small, { contentType: "text/html" }));
      await assertFails(uploadBytes(ref(anna, `${folder}/anna/a.html`), small, jpeg));
    });
    test("anyone signed in reads, only the owner deletes", async () => {
      await uploadBytes(ref(anna, path), small, jpeg);
      await assertSucceeds(getBytes(ref(bela, path)));
      await assertFails(getBytes(ref(guest, path)));
      await assertFails(deleteObject(ref(bela, path)));
      await assertSucceeds(deleteObject(ref(anna, path)));
    });
  });
}

test("anything else is closed", () => assertFails(uploadBytes(ref(anna, "other/anna/a.jpg"), small, jpeg)));
