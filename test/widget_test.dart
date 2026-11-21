// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cc105_givers_documentation/auth/login_screen.dart';
import 'package:cc105_givers_documentation/auth/forgot_password_screen.dart';
import 'package:cc105_givers_documentation/attendee/event_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  testWidgets('Login screen exposes designed fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.text('forgot passowrd?'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('Forgot password screen exposes email reset flow', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    expect(find.byKey(const Key('reset_email')), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
    expect(find.text('← Back to login'), findsOneWidget);
  });

  test('GiventsEvent preserves event fields', () {
    final event = GiventsEvent(
      id: 'event1',
      organizerId: 'organizer',
      title: 'Test Fair',
      category: 'Fair',
      description: 'Description',
      date: Timestamp.fromDate(DateTime(2026, 12, 15)),
      startTime: '09:00',
      endTime: '18:00',
      venueName: 'Convention Center',
      venueAddress: 'Rizal Street',
      city: 'Legazpi City',
      province: 'Albay',
      totalSlots: 10,
      boothFee: 2500,
    );

    expect(event.title, 'Test Fair');
    expect(event.totalSlots, 10);
    expect(event.boothFee, 2500);
  });
}
