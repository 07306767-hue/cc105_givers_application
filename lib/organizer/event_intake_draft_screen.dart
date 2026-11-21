import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventIntakeDraftScreen extends StatefulWidget {
  const EventIntakeDraftScreen({super.key});

  @override
  State<EventIntakeDraftScreen> createState() => _EventIntakeDraftScreenState();
}

class _EventIntakeDraftScreenState extends State<EventIntakeDraftScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  String _category = 'Fair';
  DateTime? _date;
  String? _draftId;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('event_intake_drafts')
        .where('organizer_profile_id', isEqualTo: uid)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      _draftId = snapshot.docs.first.id;
      _title.text = data['parsed_title'] as String? ?? '';
      _location.text = data['parsed_location'] as String? ?? '';
      _category = data['parsed_category'] as String? ?? 'Fair';
      if (data['parsed_date'] is Timestamp) {
        _date = (data['parsed_date'] as Timestamp).toDate();
      }
    } else {
      _draftId = null;
      _title.text = 'Legazpi Cultural Fair';
      _location.text = 'Legazpi City, Albay';
      _category = 'Fair';
      _date = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance.collection('event_intake_drafts').add({
        'organizer_profile_id': uid,
        'source_type': 'mock',
        'raw_source_text':
            'Mock source: Cultural Fair in Legazpi City on the selected date.',
        'parsed_title': _title.text,
        'parsed_location': _location.text,
        'parsed_category': _category,
        'parsed_date': Timestamp.fromDate(_date!),
        'draft_status': 'draft',
        'confirmed_event_id': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      final created = await FirebaseFirestore.instance
          .collection('event_intake_drafts')
          .where('organizer_profile_id', isEqualTo: uid)
          .limit(1)
          .get();
      if (created.docs.isNotEmpty) _draftId = created.docs.first.id;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _updateStatus(String status) async {
    if (_draftId == null) return;
    setState(() => _busy = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final draftRef = firestore
          .collection('event_intake_drafts')
          .doc(_draftId);
      String? confirmedEventId;

      if (status == 'confirmed') {
        final eventRef = firestore.collection('events').doc();
        confirmedEventId = eventRef.id;
        batch.set(eventRef, {
          'event_id': eventRef.id,
          'organizer_profile_id': FirebaseAuth.instance.currentUser!.uid,
          'event_title': _title.text.trim(),
          'event_category': _category,
          'event_description': 'Mock intake draft',
          'event_date': _date == null
              ? Timestamp.now()
              : Timestamp.fromDate(_date!),
          'start_time': '09:00',
          'end_time': '18:00',
          'venue_name': _location.text.trim(),
          'venue_address': _location.text.trim(),
          'city': 'Legazpi City',
          'province': 'Albay',
          'total_slots': 0,
          'booth_fee': 0,
          'event_status': 'draft',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      batch.update(draftRef, {
        'parsed_title': _title.text.trim(),
        'parsed_location': _location.text.trim(),
        'parsed_category': _category,
        'parsed_date': _date == null ? null : Timestamp.fromDate(_date!),
        'draft_status': status,
        'confirmed_event_id': confirmedEventId,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'discarded' ? 'Draft discarded.' : 'Draft confirmed.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Draft Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Mock source text',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mock source: Cultural Fair in Legazpi City on the selected date.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _date == null
                  ? 'Date'
                  : 'Date: ${_date!.year}-${_date!.month}-${_date!.day}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (date != null) setState(() => _date = date);
            },
          ),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'Music', child: Text('Music')),
              DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
              DropdownMenuItem(value: 'Fair', child: Text('Fair')),
            ],
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => _updateStatus('confirmed'),
            child: const Text('Confirm event'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _updateStatus('discarded'),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
