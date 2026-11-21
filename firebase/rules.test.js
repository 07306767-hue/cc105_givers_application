const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "givents-local",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });

  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("users/organizer").set({ role: "organizer", account_status: "active" });
    await db.doc("users/vendor").set({ role: "vendor", account_status: "active" });
    await db.doc("users/attendee").set({ role: "attendee", account_status: "active" });
    await db.doc("users/vendor2").set({ role: "vendor", account_status: "active" });
    await db.doc("events/event1").set({
      organizer_profile_id: "organizer",
      event_status: "published",
      booth_fee: 2500,
      total_slots: 10,
    });
    await db.doc("events/event2").set({
      organizer_profile_id: "other-organizer",
      event_status: "draft",
      booth_fee: 1000,
      total_slots: 5,
    });
    await db.doc("booth_slots/event1_A1").set({
      event_id: "event1",
      slot_code: "A1",
      slot_status: "open",
    });
    await db.doc("applications/event1_vendor").set({
      application_id: "event1_vendor",
      event_id: "event1",
      vendor_profile_id: "vendor",
      booth_fee_amount: 2500,
      application_status: "approved",
    });
    await db.doc("applications/event1_vendor2").set({
      application_id: "event1_vendor2",
      event_id: "event1",
      vendor_profile_id: "vendor",
      booth_fee_amount: 2500,
      application_status: "pending",
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

it("attendee cannot create an event", async () => {
  const db = testEnv.authenticatedContext("attendee").firestore();
  await assertFails(db.collection("events").add({
    organizer_profile_id: "attendee",
    event_status: "draft",
    total_slots: 10,
  }));
});

it("vendor cannot read another user's users document", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.doc("users/attendee").get());
});

it("organizer cannot edit another organizer's event", async () => {
  const db = testEnv.authenticatedContext("organizer").firestore();
  await assertFails(db.doc("events/event2").update({ event_title: "Changed" }));
});

it("vendor cannot approve their own application", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.doc("applications/event1_vendor2").update({
    application_status: "approved",
  }));
});

it("vendor cannot pay a pending application", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.collection("payments").add({
    application_id: "event1_vendor2",
    event_id: "event1",
    vendor_profile_id: "vendor",
    amount: 2500,
    payment_status: "pending",
  }));
});

it("vendor cannot use a wrong payment amount", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.collection("payments").add({
    application_id: "event1_vendor",
    event_id: "event1",
    vendor_profile_id: "vendor",
    amount: 100,
    payment_status: "pending",
  }));
});

it("vendor cannot create a duplicate application", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.doc("applications/event1_vendor").set({
    event_id: "event1",
    vendor_profile_id: "vendor",
    booth_fee_amount: 2500,
    requested_slot_id: "event1_A1",
    application_status: "pending",
  }));
});

it("role cannot be changed from the app", async () => {
  const db = testEnv.authenticatedContext("attendee").firestore();
  await assertFails(db.doc("users/attendee").update({ role: "organizer" }));
});

it("vendor profile cannot change verification status", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("vendor_profiles/vendor").set({
      verification_status: "pending",
    });
  });
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.doc("vendor_profiles/vendor").update({
    verification_status: "verified",
  }));
});

it("restricted collections deny reads and writes", async () => {
  const db = testEnv.authenticatedContext("vendor").firestore();
  await assertFails(db.doc("vendor_documents/document1").get());
  await assertFails(db.doc("password_reset_requests/request1").get());
});
