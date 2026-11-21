import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: true,
);

Future<void> connectFirebaseEmulators() async {
  if (!useFirebaseEmulators) {
    return;
  }

  final host = kIsWeb
      ? 'localhost'
      : (defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : 'localhost');

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
}
