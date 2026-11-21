import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _tab = 'All';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipient_user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();
    if (!mounted) return;
    setState(() {
      _notifications = snapshot.docs;
      _loading = false;
    });
  }

  int get _unread =>
      _notifications.where((item) => item.data()['is_read'] == false).length;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered =>
      _tab == 'Unread'
      ? _notifications.where((item) => item.data()['is_read'] == false).toList()
      : _notifications;

  Future<void> _markRead(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) async {
    await notification.reference.update({
      'is_read': true,
      'read_at': FieldValue.serverTimestamp(),
    });
    await _load();
  }

  Future<void> _markAllRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final notification in _notifications) {
      if (notification.data()['is_read'] == false) {
        batch.update(notification.reference, {
          'is_read': true,
          'read_at': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    await _load();
  }

  String _typeLabel(String type) {
    return switch (type) {
      'application' => 'APPLICATION',
      'payment' => 'PAYMENT',
      'event' => 'EVENT CHANGE',
      'lost_found' => 'LOST & FOUND',
      _ => 'UPDATE',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$_unread unread · Applications, payments & event updates',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        Row(
          children: [
            for (final tab in ['All', 'Unread'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ChoiceChip(
                    label: Text(
                      tab == 'All'
                          ? 'All (${_notifications.length})'
                          : 'Unread ($_unread)',
                    ),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    final data = notification.data();
                    final unread = data['is_read'] == false;
                    final createdAt = data['created_at'] as Timestamp?;
                    return Card(
                      child: ListTile(
                        onTap: unread ? () => _markRead(notification) : null,
                        title: Text(data['title'] as String? ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabel(
                                data['notification_type'] as String? ?? '',
                              ),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(data['message'] as String? ?? ''),
                            if (createdAt != null)
                              Text(
                                createdAt.toDate().toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        trailing: unread
                            ? const Icon(
                                Icons.circle,
                                size: 10,
                                color: Colors.red,
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
