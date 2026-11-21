# cc105_givers_documentation

# Givents

Flutter and Firebase mobile app for events and Lost and Found.

## Run the Flutter app

```powershell
flutter pub get
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The emulator flag is enabled by default. For a real Spark project, pass:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=false `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_PROJECT_ID=...
```

## Run the Firebase Emulator Suite

```powershell
cd firebase
npx firebase-tools emulators:start --only auth,firestore
```

The emulator ports are Auth `9099` and Firestore `8080`.

## Free-only checklist

- Keep Firebase on the Spark (free) plan.
- Do not link a billing account or enable pay-per-use services.
- Do not run Cloud Functions, Storage, Firebase Hosting, or server-side setup.
- Use Firebase Authentication, Cloud Firestore, Remote Config, Crashlytics, and Analytics only.
- Do not add collections beyond the approved data model.

## Seed and rules tests

Start the emulator suite, then run:

```powershell
cd firebase
npm install
npm run seed
npm run test:rules
```

## Firebase Console setup

1. Open Firebase Console and select the Givents project.
2. Open Project settings, verify Google Analytics is enabled, and keep the project on Spark.
3. Open Crashlytics and enable Crashlytics for the Android app.
4. Open Remote Config and create:
   - `gcash_force_fail`: boolean, default `false`
   - `max_booth_slots`: number, default `400`
   - `lost_found_categories`: JSON list default `["Personal item","Electronics","Clothing","Documents","Bags","Keys","Jewelry","Other"]`
   - `event_categories`: JSON list default `["Music","Workshop","Fair","Trade fair & bazaar"]`
5. Publish the Remote Config parameter values.
6. Run `dart pub global activate flutterfire_cli`, then `flutterfire configure` in the project root.
7. Rebuild the Android app and verify DebugView and Crashlytics in the Firebase Console.
# cc105_givers_application
