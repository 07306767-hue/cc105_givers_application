import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.roleLabel});

  final String? roleLabel;

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
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

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
    } catch (e) {
      debugPrint('Failed to load notifications: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load notifications: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  int get _unread {
    return _notifications
        .where((item) => item.data()['is_read'] == false)
        .length;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    if (_tab == 'Unread') {
      return _notifications
          .where((item) => item.data()['is_read'] == false)
          .toList();
    }

    return _notifications;
  }

  Future<void> _markRead(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) async {
    try {
      await notification.reference.update({
        'is_read': true,
        'read_at': FieldValue.serverTimestamp(),
      });

      await _load();
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notification: $e')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
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
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notifications: $e')),
      );
    }
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
    return Material(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_unread unread · ${widget.roleLabel ?? 'Applications, payments & event updates'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: _unread == 0 ? null : _markAllRead,
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
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
                              onSelected: (_) {
                                setState(() {
                                  _tab = tab;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No notifications'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final notification = _filtered[index];
                              final data = notification.data();

                              final unread = data['is_read'] == false;

                              final createdAt =
                                  data['created_at'] as Timestamp?;

                              return Card(
                                child: ListTile(
                                  onTap: unread
                                      ? () => _markRead(notification)
                                      : null,
                                  title: Text(data['title'] as String? ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _typeLabel(
                                          data['notification_type']
                                                  as String? ??
                                              '',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      Text(data['message'] as String? ?? ''),
                                      if (createdAt != null)
                                        Text(
                                          createdAt.toDate().toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
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
                ),
              ],
            ),
    );
  }
}
