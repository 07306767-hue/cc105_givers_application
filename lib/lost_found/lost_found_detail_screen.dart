import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/givents_services.dart';

class LostFoundDetailScreen extends StatelessWidget {
  const LostFoundDetailScreen({super.key, required this.reportId});

  final String reportId;

  Future<Map<String, dynamic>?> _loadReporter(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(uid)
        .get();
    return snapshot.data();
  }

  Future<bool> _canReturn(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final role = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (role.data()?['role'] != 'organizer') return false;
    final eventId = data['event_id'] as String?;
    if (eventId == null) return false;
    final event = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();
    return event.data()?['organizer_profile_id'] == uid;
  }

  Future<void> _claim(BuildContext context, Map<String, dynamic> report) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final claimRef = FirebaseFirestore.instance
        .collection('lost_found_claims')
        .doc('${reportId}_$uid');
    final existing = await claimRef.get();
    if (existing.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already submitted a claim.')),
      );
      return;
    }
    if (!context.mounted) return;
    final ownership = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Claim item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Ownership details'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit claim'),
            ),
          ],
        );
      },
    );
    if (ownership == null || ownership.isEmpty) return;
    await claimRef.set({
      'claim_id': '${reportId}_$uid',
      'report_id': reportId,
      'claimant_user_id': uid,
      'claim_status': 'pending',
      'ownership_details': ownership,
      'claim_description': ownership,
      'claimed_at': FieldValue.serverTimestamp(),
      'resolved_at': null,
    });
    await GiventsAnalyticsService.instance.claimItemSubmitted(reportId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Claim submitted.')));
  }

  Future<void> _markReturned(
    BuildContext context,
    Map<String, dynamic> report,
  ) async {
    if (!await _canReturn(report)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the related organizer can return this item.'),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('lost_found_reports')
        .doc(reportId)
        .update({
          'report_status': 'returned',
          'returned_at': FieldValue.serverTimestamp(),
          'returned_confirmed_by_user_id':
              FirebaseAuth.instance.currentUser!.uid,
        });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Item marked returned.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('lost_found_reports')
            .doc(reportId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = snapshot.data!.data();
          if (report == null) {
            return const Center(child: Text('Report not found.'));
          }
          final reporterId = report['reporter_user_id'] as String?;
          final type = report['report_type'] as String? ?? 'lost';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                report['item_name'] as String? ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${type.toUpperCase()} • ${report['report_status'] ?? 'open'}',
              ),
              const SizedBox(height: 12),
              Text(report['description'] as String? ?? ''),
              const SizedBox(height: 12),
              Text('Category: ${report['category'] ?? ''}'),
              Text('Place: ${report['location_found'] ?? ''}'),
              if (report['reported_at'] is Timestamp)
                Text(
                  'Reported: ${(report['reported_at'] as Timestamp).toDate()}',
                ),
              const SizedBox(height: 16),
              if (reporterId != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: _loadReporter(reporterId),
                  builder: (context, reporterSnapshot) {
                    final reporter = reporterSnapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reporter',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(reporter?['display_name'] as String? ?? ''),
                        Text(reporter?['masked_contact'] as String? ?? ''),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Contact reporter'),
              ),
              if (type == 'found')
                FilledButton(
                  onPressed: () => _claim(context, report),
                  child: const Text('Claim this item'),
                ),
              const SizedBox(height: 16),
              FutureBuilder<bool>(
                future: _canReturn(report),
                builder: (context, canReturnSnapshot) {
                  if (canReturnSnapshot.data != true) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Organizer controls',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: report['report_status'] == 'returned'
                                ? null
                                : () => _markReturned(context, report),
                            child: const Text('Mark as returned'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
