import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../notifications/notifications_screen.dart';
import 'event_models.dart';
import 'event_detail_screen.dart';
import '../services/givents_services.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.role});

  final GiventsRole role;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _searchController = TextEditingController();
  final List<GiventsEvent> _events = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _events.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      var query = FirebaseFirestore.instance
          .collection('events')
          .where('event_status', isEqualTo: 'published')
          .orderBy('event_date')
          .limit(20);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      final snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        _events.addAll(snapshot.docs.map(GiventsEvent.fromSnapshot));
        _lastDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        _hasMore = snapshot.docs.length == 20;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load events.')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<GiventsEvent> get _filteredEvents {
    final search = _searchController.text.trim().toLowerCase();
    return _events.where((event) {
      final categoryMatches = _category == 'All' || event.category == _category;
      final searchMatches =
          search.isEmpty || event.title.toLowerCase().contains(search);
      return categoryMatches && searchMatches;
    }).toList();
  }

  Future<int> _openSlotCount(String eventId) async {
    final result = await FirebaseFirestore.instance
        .collection('booth_slots')
        .where('event_id', isEqualTo: eventId)
        .where('slot_status', isEqualTo: 'open')
        .count()
        .get();
    return result.count ?? 0;
  }

  String _formatDate(GiventsEvent event) {
    final date = event.date.toDate();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('event_search'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final category in [
                'All',
                ...GiventsRemoteConfigService.instance.eventCategories,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              IconButton(
                tooltip: 'Filter',
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadInitial,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Upcoming Events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                        );
                      }
                      final event = filtered[index - 1];
                      return _EventCard(
                        event: event,
                        dateLabel: _formatDate(event),
                        openSlotCount: () => _openSlotCount(event.id),
                        onTap: () async {
                          await GiventsAnalyticsService.instance.viewEvent(
                            event.id,
                            event.category,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                event: event,
                                role: widget.role,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.dateLabel,
    required this.openSlotCount,
    required this.onTap,
  });

  final GiventsEvent event;
  final String dateLabel;
  final Future<int> Function() openSlotCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('$dateLabel  •  ${event.startTime}–${event.endTime}'),
              const SizedBox(height: 4),
              Text('${event.venueName}, ${event.city}, ${event.province}'),
              const SizedBox(height: 10),
              FutureBuilder<int>(
                future: openSlotCount(),
                builder: (context, snapshot) {
                  final open = snapshot.data ?? 0;
                  return Text(
                    '$open / ${event.totalSlots} Open Slots',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
