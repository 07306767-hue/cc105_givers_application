const admin = require("firebase-admin");

process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

admin.initializeApp({ projectId: "givents-database" });

const auth = admin.auth();
const db = admin.firestore();
const timestamp = admin.firestore.Timestamp;

async function ensureUser(email, password, role, fullName, contactNumber) {
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({ email, password, displayName: fullName });
  }

  await db.doc(`users/${user.uid}`).set({
    uid: user.uid,
    email,
    full_name: fullName,
    contact_number: contactNumber,
    role,
    account_status: "active",
    registration_id: role === "attendee" ? null : `REG-${role.toUpperCase()}-001`,
    created_at: timestamp.now(),
  });
  await db.doc(`public_profiles/${user.uid}`).set({
    uid: user.uid,
    display_name: fullName,
    masked_contact: contactNumber,
    updated_at: timestamp.now(),
  });
  return user.uid;
}

async function seed() {
  const attendeeId = await ensureUser("attendee@givents.test", "Attendee!123456", "attendee", "Attendee Test", "+63 9•• ••• 1001");
  const organizerId = await ensureUser("organizer@givents.test", "Organizer!123456", "organizer", "Legazpi Events Org", "+63 9•• ••• 2001");
  const vendorId = await ensureUser("vendor@givents.test", "Vendor!123456", "vendor", "Vendor One", "+63 9•• ••• 3001");
  const vendorTwoId = await ensureUser("vendor2@givents.test", "Vendor2!123456", "vendor", "Vendor Two", "+63 9•• ••• 3002");
  const vendorThreeId = await ensureUser("vendor3@givents.test", "Vendor3!123456", "vendor", "Vendor Three", "+63 9•• ••• 3003");

  await db.doc(`organizer_profiles/${organizerId}`).set({
    organizer_profile_id: organizerId,
    organization_name: "Legazpi Events Org",
    organizer_type: "Event organizer",
    short_bio: "Community events in Legazpi City.",
    area: "Legazpi City",
    contact_person: "Organizer Test",
    email: "organizer@givents.test",
    phone_number: "+63 9•• ••• 2001",
    organizer_address: "Legazpi City, Albay",
    created_at: timestamp.now(),
    updated_at: timestamp.now(),
  });

  const vendorProfiles = [
    [vendorId, "Vendor One", "REG-VENDOR-001", "verified"],
    [vendorTwoId, "Vendor Two", "REG-VENDOR-002", "pending"],
    [vendorThreeId, "Vendor Three", "REG-VENDOR-003", "not_verified"],
  ];
  for (const [id, name, registrationId, verificationStatus] of vendorProfiles) {
    await db.doc(`vendor_profiles/${id}`).set({
      vendor_profile_id: id,
      business_name: name,
      owner_name: name,
      product_category: "Food",
      product_description: "Food and beverages",
      registration_id: registrationId,
      masked_contact: "+63 9•• ••• 3000",
      verification_status: verificationStatus,
      created_at: timestamp.now(),
      updated_at: timestamp.now(),
    });
  }

  const eventRef = await db.collection("events").add({
    event_id: "pending",
    organizer_profile_id: organizerId,
    event_title: "Albay Music and Trade Fair",
    event_category: "Fair",
    event_description: "A community music and trade fair in Legazpi City.",
    event_date: timestamp.fromDate(new Date("2026-12-15T00:00:00+08:00")),
    start_time: "09:00",
    end_time: "18:00",
    venue_name: "Legazpi Convention Center",
    venue_address: "Rizal Street",
    city: "Legazpi City",
    province: "Albay",
    latitude: 13.1391,
    longitude: 123.7438,
    total_slots: 10,
    booth_fee: 2500,
    event_status: "published",
    created_at: timestamp.now(),
    published_at: timestamp.now(),
  });
  await eventRef.update({ event_id: eventRef.id });

  const vendorIds = [vendorId, vendorTwoId, vendorThreeId];
  const applications = [];
  for (let i = 0; i < 10; i++) {
    const slotCode = `A${i + 1}`;
    await db.doc(`booth_slots/${eventRef.id}_${slotCode}`).set({
      slot_id: `${eventRef.id}_${slotCode}`,
      event_id: eventRef.id,
      slot_code: slotCode,
      slot_status: i < 3 ? "reserved" : "open",
      reserved_application_id: i < 3 ? `${eventRef.id}_${vendorIds[i]}` : null,
      reserved_at: i < 3 ? timestamp.now() : null,
    });
  }

  for (let i = 0; i < 3; i++) {
    const applicationId = `${eventRef.id}_${vendorIds[i]}`;
    const status = i === 0 ? "approved" : i === 1 ? "pending" : "rejected";
    await db.doc(`applications/${applicationId}`).set({
      application_id: applicationId,
      event_id: eventRef.id,
      vendor_profile_id: vendorIds[i],
      vendor_name: vendorProfiles[i][1],
      products_to_sell: "Local food and crafts",
      booth_fee_amount: 2500,
      requested_slot_id: `${eventRef.id}_A${i + 1}`,
      application_status: status,
      rejection_reason: status === "rejected" ? "Incomplete sample products" : null,
      applied_at: timestamp.now(),
      reviewed_at: status === "pending" ? null : timestamp.now(),
    });
    applications.push(applicationId);
  }

  for (let i = 0; i < 2; i++) {
    await db.doc(`payments/${applications[i]}`).set({
      payment_id: applications[i],
      application_id: applications[i],
      event_id: eventRef.id,
      vendor_profile_id: vendorIds[i],
      amount: 2500,
      idempotency_key: applications[i],
      payment_status: i === 0 ? "paid" : "pending",
      created_at: timestamp.now(),
      paid_at: i === 0 ? timestamp.now() : null,
    });
  }

  for (let i = 0; i < 4; i++) {
    await db.collection("notifications").add({
      recipient_user_id: i < 3 ? vendorIds[i] : organizerId,
      related_event_id: eventRef.id,
      related_application_id: i < 3 ? applications[i] : null,
      notification_type: i < 3 ? "application" : "event",
      title: i < 3 ? "Application update" : "Event created",
      message: i < 3 ? "Check your application status." : "Your event is now available.",
      is_read: false,
      read_at: null,
      created_at: timestamp.now(),
    });
  }

  const reportCases = [
    ["LF-0001", "Blue wallet", "lost", "Convention lobby", "open"],
    ["LF-0002", "Keys", "found", "Main entrance", "open"],
    ["LF-0003", "Phone", "lost", "Parking area", "matched"],
  ];
  for (const [code, name, reportType, location, status] of reportCases) {
    await db.doc(`lost_found_reports/${code}`).set({
      report_id: code,
      report_code: code,
      reporter_user_id: attendeeId,
      event_id: eventRef.id,
      item_name: name,
      category: reportType === "found" ? "Keys" : "Personal item",
      description: `${name} reported ${reportType}.`,
      location_found: location,
      reported_at: timestamp.now(),
      report_type: reportType,
      report_status: status,
    });
  }

  await db.doc(`lost_found_claims/LF-0002_${attendeeId}`).set({
    claim_id: `LF-0002_${attendeeId}`,
    report_id: "LF-0002",
    claimant_user_id: attendeeId,
    claim_status: "pending",
    claim_description: "These appear to be my keys.",
    claimed_at: timestamp.now(),
    resolved_at: null,
  });

  console.log("Givents emulator seed complete.");
}

seed().catch((error) => {
  console.error(error);
  process.exit(1);
});
