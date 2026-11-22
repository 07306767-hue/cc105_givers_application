import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrganizerOverviewScreen extends StatefulWidget {
  const OrganizerOverviewScreen({super.key});

  @override
  State<OrganizerOverviewScreen> createState() =>
      _OrganizerOverviewScreenState();
}

class _OrganizerOverviewScreenState extends State<OrganizerOverviewScreen> {
  bool _loading = true;
  String? _error;

  int _totalEvents = 0;
  int _publishedEvents = 0;
  int _pendingApplications = 0;
  int _approvedApplications = 0;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
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

      final events = await firestore
          .collection('events')
          .where('organizer_profile_id', isEqualTo: user.uid)
          .get();

      final applications = await firestore
          .collection('applications')
          .where(
            'event_id',
            whereIn: events.docs.isEmpty
                ? ['no-event']
                : events.docs.map((event) => event.id).toList(),
          )
          .get();

      final published = events.docs
          .where((event) => event.data()['event_status'] == 'published')
          .length;

      final pending = applications.docs
          .where(
            (application) =>
                application.data()['application_status'] == 'pending',
          )
          .length;

      final approved = applications.docs
          .where(
            (application) =>
                application.data()['application_status'] == 'approved',
          )
          .length;

      final sortedEvents = [...events.docs];

      sortedEvents.sort((a, b) {
        final aDate = a.data()['created_at'] as Timestamp?;
        final bDate = b.data()['created_at'] as Timestamp?;

        return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
          aDate?.millisecondsSinceEpoch ?? 0,
        );
      });

      if (!mounted) return;

      setState(() {
        _totalEvents = events.docs.length;
        _publishedEvents = published;
        _pendingApplications = pending;
        _approvedApplications = approved;
        _recentEvents = sortedEvents.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Organizer overview error: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _summaryCard(String title, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 45, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Could not load organizer overview.'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadOverview,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Organizer Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('Here is an overview of your event activities.'),
          const SizedBox(height: 20),

          Text('Event Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              _summaryCard(
                'Total Events',
                _totalEvents,
                Icons.event_note_outlined,
              ),
              _summaryCard(
                'Published Events',
                _publishedEvents,
                Icons.public_outlined,
              ),
              _summaryCard(
                'Pending Applications',
                _pendingApplications,
                Icons.pending_actions,
              ),
              _summaryCard(
                'Approved Applications',
                _approvedApplications,
                Icons.check_circle_outline,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text('Recent Events', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          if (_recentEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No events created yet.')),
            )
          else
            ..._recentEvents.map((event) {
              final data = event.data();

              final title = data['event_title'] as String? ?? 'Untitled event';

              final venue =
                  data['venue_name'] as String? ?? 'No venue provided';

              final status = data['event_status'] as String? ?? 'draft';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$venue • $status'),
                ),
              );
            }),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _loadOverview,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Overview'),
          ),
        ],
      ),
    );
  }
}
