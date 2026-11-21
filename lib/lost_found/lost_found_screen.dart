import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'lost_found_detail_screen.dart';
import 'report_lost_found_screen.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final _search = TextEditingController();
  String _filter = 'All items';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reports = [];
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
    final snapshot = await FirebaseFirestore.instance
        .collection('lost_found_reports')
        .orderBy('reported_at', descending: true)
        .limit(20)
        .get();
    if (!mounted) return;
    setState(() {
      _reports = snapshot.docs;
      _loading = false;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final term = _search.text.trim().toLowerCase();
    return _reports.where((report) {
      final data = report.data();
      final type = data['report_type'] as String? ?? 'lost';
      final matchesType = _filter == 'All items'
          ? true
          : _filter == 'Lost'
          ? type == 'lost'
          : _filter == 'Found'
          ? type == 'found'
          : data['reporter_user_id'] == uid;
      final itemName = (data['item_name'] as String? ?? '').toLowerCase();
      return matchesType && (term.isEmpty || itemName.contains(term));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Lost and Found')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportLostFoundScreen(onPublished: _load),
                    ),
                  ),
                  child: const Text('Report an item'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final filter in const [
                  'All items',
                  'Lost',
                  'Found',
                  'My reports',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final report = filtered[index];
                        final data = report.data();
                        final type = data['report_type'] as String? ?? 'lost';
                        final status =
                            data['report_status'] as String? ?? 'open';
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                            ),
                            title: Text(data['item_name'] as String? ?? ''),
                            subtitle: Text(
                              '${type.toUpperCase()} • $status\n'
                              '${data['location_found'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              type == 'found'
                                  ? 'Claim item →'
                                  : 'View report →',
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LostFoundDetailScreen(reportId: report.id),
                              ),
                            ),
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
