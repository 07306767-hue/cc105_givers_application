import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_event_screen.dart';

class EventIntakeDraftScreen extends StatelessWidget {
  const EventIntakeDraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    final draftsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('organizer_profile_id', isEqualTo: uid)
        .where('event_status', isEqualTo: 'draft');

    return Scaffold(
      appBar: AppBar(title: const Text('My Draft Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: draftsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load drafts: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drafts = snapshot.data?.docs ?? [];

          if (drafts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.drafts_outlined, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'No draft events yet.',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 6),
                    Text('Events saved as drafts will appear here.'),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final document = drafts[index];
              final data = document.data();

              final title = data['event_title'] as String? ?? 'Untitled event';

              final venue =
                  data['venue_name'] as String? ?? 'No venue provided';

              final date = data['event_date'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateEventScreen(draftId: document.id),
                      ),
                    );
                  },
                  leading: const Icon(Icons.drafts_outlined),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$venue\n'
                    '${date == null ? 'Date not set' : MaterialLocalizations.of(context).formatMediumDate(date.toDate())}\n'
                    'Draft',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.edit_outlined),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
