import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/givents_services.dart';

class OrganizerApplicationsScreen extends StatefulWidget {
  const OrganizerApplicationsScreen({super.key});

  @override
  State<OrganizerApplicationsScreen> createState() =>
      _OrganizerApplicationsScreenState();
}

class _OrganizerApplicationsScreenState
    extends State<OrganizerApplicationsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final events = await FirebaseFirestore.instance
        .collection('events')
        .where('organizer_profile_id', isEqualTo: uid)
        .get();
    final eventIds = events.docs.map((doc) => doc.id).toList();
    final all = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final eventId in eventIds) {
      final snapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('event_id', isEqualTo: eventId)
          .get();
      all.addAll(snapshot.docs);
    }
    if (!mounted) return;
    setState(() {
      _applications = all;
      _loading = false;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    final term = _search.text.trim().toLowerCase();
    return _applications.where((application) {
      final data = application.data();
      final status = data['application_status'] as String? ?? 'pending';
      final name = (data['vendor_name'] as String? ?? '').toLowerCase();
      final statusMatches =
          _filter == 'All' || status.toLowerCase() == _filter.toLowerCase();
      return statusMatches && (term.isEmpty || name.contains(term));
    }).toList();
  }

  int _countStatus(String status) => _applications.where((application) {
    return (application.data()['application_status'] as String? ?? 'pending') ==
        status;
  }).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search vendor name',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final status in const [
                'All',
                'Pending',
                'Approved',
                'Rejected',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      status == 'All'
                          ? 'All (${_applications.length})'
                          : '$status (${status == 'Pending'
                                ? _countStatus('pending')
                                : status == 'Approved'
                                ? _countStatus('approved')
                                : _countStatus('rejected')})',
                    ),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final application = filtered[index];
                    final data = application.data();
                    return Card(
                      child: ListTile(
                        title: Text(data['vendor_name'] as String? ?? ''),
                        subtitle: Text(
                          '${data['application_status']} • ₱${(data['booth_fee_amount'] as num).toStringAsFixed(0)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ApplicationDetailScreen(
                              applicationId: application.id,
                              onChanged: _load,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.onChanged,
  });

  final String applicationId;
  final Future<void> Function() onChanged;

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _busy = false;
  final _rejectionReason = TextEditingController();

  @override
  void dispose() {
    _rejectionReason.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _busy = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final applicationRef = firestore
          .collection('applications')
          .doc(widget.applicationId);
      final application = await applicationRef.get();
      final data = application.data()!;
      final batch = firestore.batch();
      batch.update(applicationRef, {
        'application_status': status,
        'rejection_reason': status == 'rejected'
            ? _rejectionReason.text.trim()
            : null,
        'reviewed_at': FieldValue.serverTimestamp(),
      });
      batch.set(firestore.collection('notifications').doc(), {
        'recipient_user_id': data['vendor_profile_id'],
        'related_event_id': data['event_id'],
        'related_application_id': widget.applicationId,
        'notification_type': 'application',
        'title': status == 'approved'
            ? 'Application approved'
            : 'Application rejected',
        'message': 'Your booth application status was updated.',
        'is_read': false,
        'read_at': null,
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await GiventsAnalyticsService.instance.applicationDecision(
        data['event_id'] as String,
        status,
      );
      await widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update application.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Review')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('applications')
            .doc(widget.applicationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data()!;
          final status = data['application_status'] as String? ?? 'pending';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data['vendor_name'] as String? ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('Status: $status'),
              Text('Products: ${data['products_to_sell'] ?? ''}'),
              Text(
                'Booth fee: ₱${(data['booth_fee_amount'] as num).toStringAsFixed(0)}',
              ),
              Text('Requested slot: ${data['requested_slot_id'] ?? ''}'),
              if (status == 'pending') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _rejectionReason,
                  decoration: const InputDecoration(
                    labelText: 'Rejection reason (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _updateStatus('rejected'),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _updateStatus('approved'),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
