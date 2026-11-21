import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/givents_services.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _venueAddress = TextEditingController();
  final _city = TextEditingController(text: 'Legazpi City');
  final _province = TextEditingController(text: 'Albay');
  final _slots = TextEditingController();
  final _fee = TextEditingController();
  String _category = 'Fair';
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _draftId;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _venue,
      _venueAddress,
      _city,
      _province,
      _slots,
      _fee,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _eventData(String status) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return {
      'organizer_profile_id': uid,
      'event_title': _title.text.trim(),
      'event_category': _category,
      'event_description': _description.text.trim(),
      'event_date': Timestamp.fromDate(_date!),
      'start_time': _timeString(_startTime!),
      'end_time': _timeString(_endTime!),
      'venue_name': _venue.text.trim(),
      'venue_address': _venueAddress.text.trim(),
      'city': _city.text.trim(),
      'province': _province.text.trim(),
      'total_slots': int.parse(_slots.text.trim()),
      'booth_fee': double.parse(_fee.text.trim()),
      'event_status': status,
      'created_at': FieldValue.serverTimestamp(),
      'published_at': status == 'published'
          ? FieldValue.serverTimestamp()
          : null,
    };
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    if (_date == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose event date, start time, and end time.'),
        ),
      );
      return false;
    }
    final slots = int.tryParse(_slots.text.trim()) ?? 0;
    final cap = GiventsRemoteConfigService.instance.maxBoothSlots;
    if (slots < 1 || slots > cap) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Slots must be from 1 to $cap.')));
      return false;
    }
    return true;
  }

  Future<void> _saveDraft() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final data = _eventData('draft');
      if (_draftId == null) {
        final ref = await FirebaseFirestore.instance
            .collection('events')
            .add(data);
        _draftId = ref.id;
        await ref.update({'event_id': ref.id});
      } else {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(_draftId)
            .set(data, SetOptions(merge: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not save draft.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review() async {
    if (!_validate()) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewPublishScreen(
          draftId: _draftId,
          eventData: _eventData('draft'),
          slotCount: int.parse(_slots.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('event_title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Event title *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('event_category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Event category *'),
              items: GiventsRemoteConfigService.instance.eventCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('event_description'),
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description *'),
              maxLines: 4,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _date == null
                    ? 'Event date *'
                    : 'Event date: ${_date!.year}-${_date!.month}-${_date!.day}',
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
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _startTime == null
                          ? 'Starts at *'
                          : 'Starts ${_timeString(_startTime!)}',
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => _startTime = time);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _endTime == null
                          ? 'Ends at *'
                          : 'Ends ${_timeString(_endTime!)}',
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => _endTime = time);
                    },
                  ),
                ),
              ],
            ),
            const Text('Philippine Standard Time UTC+08:00'),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('event_venue'),
              controller: _venue,
              decoration: const InputDecoration(labelText: 'Venue *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueAddress,
              decoration: const InputDecoration(labelText: 'Venue address *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _province,
              decoration: const InputDecoration(labelText: 'Province *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Pin your event on the map'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('event_slots'),
              controller: _slots,
              decoration: const InputDecoration(labelText: 'Slots *'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  int.tryParse(value ?? '') == null ? 'Enter a number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('event_fee'),
              controller: _fee,
              decoration: const InputDecoration(labelText: 'Booth fee (PHP) *'),
              keyboardType: TextInputType.number,
              validator: (value) => double.tryParse(value ?? '') == null
                  ? 'Enter an amount'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Event photo (JPG/PNG)'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _saveDraft,
                    child: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _review,
                    child: const Text('Review event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewPublishScreen extends StatefulWidget {
  const ReviewPublishScreen({
    super.key,
    required this.draftId,
    required this.eventData,
    required this.slotCount,
  });

  final String? draftId;
  final Map<String, dynamic> eventData;
  final int slotCount;

  @override
  State<ReviewPublishScreen> createState() => _ReviewPublishScreenState();
}

class _ReviewPublishScreenState extends State<ReviewPublishScreen> {
  bool _publishing = false;

  Future<void> _publish() async {
    if (widget.slotCount > 400) return;
    setState(() => _publishing = true);
    try {
      final firestore = FirebaseFirestore.instance;
      DocumentReference<Map<String, dynamic>> eventRef;
      if (widget.draftId != null) {
        eventRef = firestore.collection('events').doc(widget.draftId);
      } else {
        eventRef = firestore.collection('events').doc();
      }

      final batch = firestore.batch();
      final eventData = Map<String, dynamic>.from(widget.eventData);
      eventData['event_id'] = eventRef.id;
      eventData['event_status'] = 'published';
      eventData['published_at'] = FieldValue.serverTimestamp();
      batch.set(eventRef, eventData);

      for (var i = 1; i <= widget.slotCount; i++) {
        final code = 'A$i';
        final slotRef = firestore
            .collection('booth_slots')
            .doc('${eventRef.id}_$code');
        batch.set(slotRef, {
          'slot_id': '${eventRef.id}_$code',
          'event_id': eventRef.id,
          'slot_code': code,
          'slot_status': 'open',
          'reserved_application_id': null,
          'reserved_at': null,
        });
      }
      batch.set(firestore.collection('notifications').doc(), {
        'recipient_user_id': FirebaseAuth.instance.currentUser!.uid,
        'related_event_id': eventRef.id,
        'related_application_id': null,
        'notification_type': 'event',
        'title': 'Event published',
        'message': 'Your event is now published.',
        'is_read': false,
        'read_at': null,
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event published.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not publish event.')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.eventData;
    return Scaffold(
      appBar: AppBar(title: const Text('Review and Publish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            data['event_title'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('Category: ${data['event_category']}'),
          Text('Venue: ${data['venue_name']}'),
          Text('Address: ${data['venue_address']}'),
          Text('${data['city']}, ${data['province']}'),
          Text('Slots: ${data['total_slots']}'),
          Text(
            'Booth fee: ₱${(data['booth_fee'] as double).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 16),
          Text(data['event_description'] as String),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
    );
  }
}
