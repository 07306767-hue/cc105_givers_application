import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class GiventsRemoteConfigService {
  GiventsRemoteConfigService._();

  static final instance = GiventsRemoteConfigService._();
  FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await remoteConfig.setDefaults({
      'gcash_force_fail': false,
      'max_booth_slots': 400,
      'lost_found_categories': '["Personal item","Electronics","Clothing","Documents","Bags","Keys","Jewelry","Other"]',
      'event_categories': '["Music","Workshop","Fair","Trade fair & bazaar"]',
    });
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const bool.fromEnvironment('dart.vm.product')
            ? const Duration(hours: 12)
            : const Duration(minutes: 1),
      ),
    );
    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // In-app defaults remain available.
    }
  }

  bool get gcashForceFail => remoteConfig.getBool('gcash_force_fail');

  int get maxBoothSlots {
    final value = remoteConfig.getInt('max_booth_slots');
    return value >= 1 && value <= 400 ? value : 400;
  }

  List<String> get lostFoundCategories =>
      _decodeStringList(remoteConfig.getString('lost_found_categories'));

  List<String> get eventCategories =>
      _decodeStringList(remoteConfig.getString('event_categories'));

  List<String> _decodeStringList(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }
}

class GiventsAnalyticsService {
  GiventsAnalyticsService._();

  static final instance = GiventsAnalyticsService._();
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  Future<void> setRole(String uid, String role) async {
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      await FirebaseCrashlytics.instance.setCustomKey('role', role);
    }
    await analytics.setUserId(id: uid);
    await analytics.setUserProperty(name: 'role', value: role);
  }

  Future<void> signUp(String role) => analytics.logEvent(
    name: 'sign_up',
    parameters: {'method': 'email', 'role': role},
  );

  Future<void> login(String role) => analytics.logEvent(
    name: 'login',
    parameters: {'method': 'email', 'role': role},
  );

  Future<void> forgotPasswordRequested() =>
      analytics.logEvent(name: 'forgot_password_requested');

  Future<void> viewEvent(String eventId, String category) => analytics.logEvent(
    name: 'view_event',
    parameters: {'event_id': eventId, 'event_category': category},
  );

  Future<void> applySlotTapped(String eventId) => analytics.logEvent(
    name: 'apply_slot_tapped',
    parameters: {'event_id': eventId},
  );

  Future<void> applicationSubmitted(String eventId) => analytics.logEvent(
    name: 'application_submitted',
    parameters: {'event_id': eventId},
  );

  Future<void> applicationDecision(String eventId, String decision) =>
      analytics.logEvent(
        name: 'application_decision',
        parameters: {'event_id': eventId, 'decision': decision},
      );

  Future<void> payGcashTapped(String eventId) => analytics.logEvent(
    name: 'pay_gcash_tapped',
    parameters: {'event_id': eventId},
  );

  Future<void> paymentResult(String result) => analytics.logEvent(
    name: 'payment_result',
    parameters: {'result': result},
  );

  Future<void> reportItemPublished(String reportType) => analytics.logEvent(
    name: 'report_item_published',
    parameters: {'report_type': reportType},
  );

  Future<void> claimItemSubmitted(String reportId) => analytics.logEvent(
    name: 'claim_item_submitted',
    parameters: {'report_id': reportId},
  );
}
