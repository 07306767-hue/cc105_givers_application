import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrganizerEventsPlaceholder extends StatelessWidget {
  const OrganizerEventsPlaceholder({
    super.key,
    required this.onCreate,
    required this.onDraft,
  });

  final VoidCallback onCreate;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please log in again.'));
    }

    final eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('organizer_profile_id', isEqualTo: uid)
        .where('event_status', isEqualTo: 'published')
        .orderBy('event_date');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: onCreate, child: const Text('Create event')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onDraft, child: const Text('Draft event')),
        const SizedBox(height: 24),

        Text(
          'My Published Events',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Could not load events: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data?.docs ?? [];

            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('You have no published events yet.')),
              );
            }

            return Column(
              children: events.map((event) {
                final data = event.data();
                final title =
                    data['event_title'] as String? ?? 'Untitled event';
                final venue =
                    data['venue_name'] as String? ?? 'No venue provided';
                final date = data['event_date'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$venue\n'
                      '${date == null ? 'Date not set' : MaterialLocalizations.of(context).formatMediumDate(date.toDate())}\n'
                      'Published',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.check_circle_outline),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
