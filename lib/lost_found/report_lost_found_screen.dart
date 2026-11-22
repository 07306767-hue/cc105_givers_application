import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/givents_services.dart';

class ReportLostFoundScreen extends StatefulWidget {
  const ReportLostFoundScreen({super.key, required this.onPublished});

  final Future<void> Function() onPublished;

  @override
  State<ReportLostFoundScreen> createState() => _ReportLostFoundScreenState();
}

class _ReportLostFoundScreenState extends State<ReportLostFoundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemName = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  String _reportType = 'lost';
  String _category = 'Personal item';
  String? _eventId;
  DateTime? _date;
  TimeOfDay? _time;
  bool _publishing = false;

  @override
  void dispose() {
    _itemName.dispose();
    _description.dispose();
    _place.dispose();
    super.dispose();
  }

  String _reportCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return 'LF-${List.generate(6, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose date and time.')));
      return;
    }
    setState(() => _publishing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final code = _reportCode();
      final reportedAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      await FirebaseFirestore.instance
          .collection('lost_found_reports')
          .doc(code)
          .set({
            'report_id': code,
            'report_code': code,
            'reporter_user_id': uid,
            'event_id': _eventId,
            'item_name': _itemName.text.trim(),
            'category': _category,
            'description': _description.text.trim(),
            'photo_url': null,
            'location_found': _place.text.trim(),
            'reported_at': Timestamp.fromDate(reportedAt),
            'report_type': _reportType,
            'report_status': 'open',
          });
      await widget.onPublished();
      await GiventsAnalyticsService.instance.reportItemPublished(_reportType);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report published.')));
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      debugPrint('LOST AND FOUND ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish report: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lost', label: Text('I lost an item')),
                ButtonSegment(value: 'found', label: Text('I found an item')),
              ],
              selected: {_reportType},
              onSelectionChanged: (value) =>
                  setState(() => _reportType = value.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemName,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: GiventsRemoteConfigService.instance.lostFoundCategories
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
              controller: _place,
              decoration: const InputDecoration(labelText: 'Place'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('event_status', isEqualTo: 'published')
                  .snapshots(),
              builder: (context, snapshot) {
                final events = snapshot.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _eventId,
                  decoration: const InputDecoration(labelText: 'Related event'),
                  items: events
                      .map(
                        (event) => DropdownMenuItem(
                          value: event.id,
                          child: Text(
                            event.data()['event_title'] as String? ?? event.id,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _eventId = value),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _date == null
                    ? 'Date'
                    : '${_date!.year}-${_date!.month}-${_date!.day}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _date = date);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _time == null
                    ? 'Time'
                    : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) setState(() => _time = time);
              },
            ),
            const Text(
              'Photo follows privacy limits: no full contact details are displayed.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Publish report'),
            ),
          ],
        ),
      ),
    );
  }
}
