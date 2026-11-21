import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_shell.dart';
import '../services/givents_services.dart';

class GiventsAuthService {
  GiventsAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<GiventsRole> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      await _auth.signOut();
      throw Exception('Account record was not found.');
    }

    final data = snapshot.data()!;
    if (data['account_status'] != 'active') {
      await _auth.signOut();
      throw Exception('This account is disabled.');
    }

    final role = roleFromString(data['role'] as String?);
    await GiventsAnalyticsService.instance.login(role.name);
    await GiventsAnalyticsService.instance.setRole(uid, role.name);
    return role;
  }

  Future<GiventsRole> signUp({
    required String email,
    required String fullName,
    required String contactNumber,
    required String password,
    required GiventsRole role,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final now = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), {
        'uid': uid,
        'email': email.trim(),
        'full_name': fullName.trim(),
        'contact_number': contactNumber.trim(),
        'role': role.name,
        'account_status': 'active',
        'created_at': now,
      });
      batch.set(_firestore.collection('public_profiles').doc(uid), {
        'uid': uid,
        'display_name': fullName.trim(),
        'masked_contact': maskContactNumber(contactNumber),
        'updated_at': now,
      });
      await batch.commit();
      await GiventsAnalyticsService.instance.signUp(role.name);
      await GiventsAnalyticsService.instance.setRole(uid, role.name);
      return role;
    } catch (_) {
      await credential?.user?.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      await GiventsAnalyticsService.instance.forgotPasswordRequested();
    } on FirebaseAuthException {
      // Deliberately expose the same result for existing and unknown accounts.
    }
  }

  Future<GiventsRole> roleForUid(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) throw Exception('Account record was not found.');
    final data = snapshot.data()!;
    if (data['account_status'] != 'active') {
      throw Exception('This account is disabled.');
    }
    final role = roleFromString(data['role'] as String?);
    await GiventsAnalyticsService.instance.setRole(uid, role.name);
    return role;
  }

  static GiventsRole roleFromString(String? role) {
    return switch (role) {
      'organizer' => GiventsRole.organizer,
      'vendor' => GiventsRole.vendor,
      _ => GiventsRole.attendee,
    };
  }

  static String maskContactNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return value;
    }
    if (digits.length < 10) {
      return '+63 •• ••• ${digits.substring(digits.length - 4)}';
    }
    return '+63 ${digits.substring(digits.length - 10, digits.length - 7)}•• ••• ${digits.substring(digits.length - 4)}';
  }
}
