import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/givents_services.dart';

class VendorPaymentsScreen extends StatefulWidget {
  const VendorPaymentsScreen({super.key});

  @override
  State<VendorPaymentsScreen> createState() => _VendorPaymentsScreenState();
}

class _VendorPaymentsScreenState extends State<VendorPaymentsScreen> {
  bool _loading = true;
  bool _paying = false;

  String? _error;

  final Map<String, String> _attemptKeys = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applications = [];

  Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _payments = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // LOAD VENDOR APPLICATIONS AND PAYMENTS
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in account found.');
      }

      final firestore = FirebaseFirestore.instance;

      final applications = await firestore
          .collection('applications')
          .where('vendor_profile_id', isEqualTo: user.uid)
          .get();

      final payments = await firestore
          .collection('payments')
          .where('vendor_profile_id', isEqualTo: user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _applications = applications.docs;

        _payments = {
          for (final payment in payments.docs)
            if (payment.data()['application_id'] is String)
              payment.data()['application_id'] as String: payment,
        };

        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Vendor applications loading error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // CREATE OR UPDATE PAYMENT
  Future<void> _createOrUpdatePayment(
    QueryDocumentSnapshot<Map<String, dynamic>> application,
    String status,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = application.data();
    final applicationId = application.id;
    final firestore = FirebaseFirestore.instance;

    final paymentId = _attemptKeys.putIfAbsent(
      applicationId,
      () => '${applicationId}_${DateTime.now().microsecondsSinceEpoch}',
    );

    await firestore.runTransaction((transaction) async {
      final paymentRef = firestore.collection('payments').doc(paymentId);

      final existing = await transaction.get(paymentRef);

      if (!existing.exists) {
        if (status != 'pending') {
          throw Exception('Payment must start pending');
        }

        transaction.set(paymentRef, {
          'payment_id': paymentId,
          'application_id': applicationId,
          'event_id': data['event_id'],
          'vendor_profile_id': uid,
          'amount': data['booth_fee_amount'],
          'payment_method': 'gcash',
          'idempotency_key': paymentId,
          'payment_status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'paid_at': null,
          'payment_reference': null,
          'receipt_number': null,
        });
      } else {
        if (existing.data()?['payment_status'] != 'pending') {
          throw Exception('Payment is already completed');
        }

        final paid = status == 'paid';

        transaction.update(paymentRef, {
          'payment_status': status,
          'paid_at': paid ? FieldValue.serverTimestamp() : null,
          'payment_reference': paid ? _demoPaymentReference() : null,
          'receipt_number': paid ? _demoReceiptNumber(applicationId) : null,
        });
      }
    });

    await _load();
  }

  String _demoPaymentReference() {
    final now = DateTime.now();

    final date =
        '${now.year.toString().substring(2)}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final suffix = now.microsecondsSinceEpoch.toString().substring(8);

    return 'DEMO-$date-$suffix';
  }

  String _demoReceiptNumber(String applicationId) {
    final suffix = applicationId.hashCode
        .abs()
        .toString()
        .padLeft(4, '0')
        .substring(0, 4);

    return 'RCPT-$suffix';
  }

  // MOCK GCASH PAYMENT
  Future<void> _payWithGcash(
    QueryDocumentSnapshot<Map<String, dynamic>> application,
  ) async {
    if (_paying) return;

    setState(() => _paying = true);

    try {
      final existingPayment = _payments[application.id];

      if (existingPayment?.data()['payment_status'] == 'failed') {
        _attemptKeys.remove(application.id);
      }

      await _createOrUpdatePayment(application, 'pending');

      await GiventsAnalyticsService.instance.payGcashTapped(
        application.data()['event_id'] as String,
      );

      await Future<void>.delayed(const Duration(milliseconds: 900));

      final applicationId = application.id;
      final paymentId = _attemptKeys[applicationId]!;

      final result = GiventsRemoteConfigService.instance.gcashForceFail
          ? 'failed'
          : 'paid';

      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
            'payment_status': result,
            'paid_at': result == 'paid' ? FieldValue.serverTimestamp() : null,
            'payment_reference': result == 'paid'
                ? _demoPaymentReference()
                : null,
            'receipt_number': result == 'paid'
                ? _demoReceiptNumber(applicationId)
                : null,
          });

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final eventId = application.data()['event_id'] as String;
      final vendorName =
          application.data()['vendor_name'] as String? ?? 'A vendor';
      final event = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      final organizerId = event.data()?['organizer_profile_id'] as String?;

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipient_user_id': uid,
        'related_event_id': eventId,
        'related_application_id': applicationId,
        'notification_type': 'payment',
        'title': result == 'paid'
            ? 'Payment confirmed'
            : 'Payment needs retry',
        'message': result == 'paid'
            ? 'Your GCash mock payment was confirmed.'
            : 'Your GCash mock payment failed. Please retry.',
        'is_read': false,
        'read_at': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (organizerId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipient_user_id': organizerId,
          'related_event_id': eventId,
          'related_application_id': applicationId,
          'notification_type': 'payment',
          'title': result == 'paid'
              ? 'Vendor payment confirmed'
              : 'Vendor payment failed',
          'message': result == 'paid'
              ? '$vendorName completed a booth payment.'
              : '$vendorName attempted a booth payment but it failed.',
          'is_read': false,
          'read_at': null,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await _load();

      await GiventsAnalyticsService.instance.paymentResult(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == 'paid'
                ? 'GCash mock payment confirmed.'
                : 'GCash mock payment failed. Please retry.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Vendor payment error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not process mock payment: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ERROR SCREEN
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load applications.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final approved = _applications
        .where(
          (application) =>
              application.data()['application_status'] == 'approved',
        )
        .toList();

    if (_applications.isEmpty) {
      return const Center(
        child: Text('You have not submitted any applications yet.'),
      );
    }

    if (approved.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'My Applications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final application in _applications)
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(
                  application.data()['vendor_name'] as String? ??
                      'My Application',
                ),
                subtitle: Text(
                  'Status: ${application.data()['application_status'] ?? 'pending'}',
                ),
              ),
            ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: approved.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'My Applications and Payments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            );
          }

          final application = approved[index - 1];
          final data = application.data();
          final payment = _payments[application.id];

          final paymentStatus =
              payment?.data()['payment_status'] as String? ?? 'unpaid';

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['vendor_name'] as String? ?? 'Approved application',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: ₱${(data['booth_fee_amount'] as num? ?? 0).toStringAsFixed(0)}',
                  ),
                  Text('Payment status: $paymentStatus'),

                  if (paymentStatus == 'unpaid') ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _paying
                          ? null
                          : () => _payWithGcash(application),
                      child: const Text('Pay with GCash · Mock'),
                    ),
                  ],

                  if (paymentStatus == 'failed')
                    TextButton(
                      onPressed: _paying
                          ? null
                          : () => _payWithGcash(application),
                      child: const Text('Retry payment'),
                    ),

                  if (paymentStatus == 'paid')
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Payment confirmed'),
                          content: Text(
                            'Reference: ${payment?.data()['payment_reference'] ?? ''}\n'
                            'Receipt: ${payment?.data()['receipt_number'] ?? ''}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('View receipt · Payment confirmed'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
