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
  final Map<String, String> _attemptKeys = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applications = [];
  Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _payments = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final applications = await FirebaseFirestore.instance
        .collection('applications')
        .where('vendor_profile_id', isEqualTo: uid)
        .get();
    final payments = await FirebaseFirestore.instance
        .collection('payments')
        .where('vendor_profile_id', isEqualTo: uid)
        .get();
    if (!mounted) return;
    setState(() {
      _applications = applications.docs;
      _payments = {
        for (final payment in payments.docs)
          payment.data()['application_id'] as String: payment,
      };
      _loading = false;
    });
  }

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
        if (status != 'pending') throw Exception('Payment must start pending');
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
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
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
      if (result == 'paid') {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipient_user_id': uid,
          'related_event_id': application.data()['event_id'],
          'related_application_id': applicationId,
          'notification_type': 'payment',
          'title': 'Payment confirmed',
          'message': 'Your GCash mock payment was confirmed.',
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not process mock payment.')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final approved = _applications
        .where(
          (application) =>
              application.data()['application_status'] == 'approved',
        )
        .toList();
    if (approved.isEmpty) {
      return const Center(
        child: Text('Applications and payments (ASSUMPTION placeholder)'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: approved.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
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
                  'Amount: ₱${(data['booth_fee_amount'] as num).toStringAsFixed(0)}',
                ),
                Text('Status: $paymentStatus'),
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
    );
  }
}
