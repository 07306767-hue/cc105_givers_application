import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../attendee/event_models.dart';
import '../services/givents_services.dart';

class VendorApplicationScreen extends StatefulWidget {
  const VendorApplicationScreen({super.key, required this.event});

  final GiventsEvent event;

  @override
  State<VendorApplicationScreen> createState() =>
      _VendorApplicationScreenState();
}

class _VendorApplicationScreenState extends State<VendorApplicationScreen> {
  final _products = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _vendorProfile;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _openSlots = [];

  String? _selectedSlotId;
  String? _error;

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _products.dispose();
    super.dispose();
  }

  // LOAD VENDOR PROFILE AND AVAILABLE SLOTS
  Future<void> _load() async {
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

      final vendorSnapshot = await firestore
          .collection('vendor_profiles')
          .doc(user.uid)
          .get();

      final slotsSnapshot = await firestore
          .collection('booth_slots')
          .where('event_id', isEqualTo: widget.event.id)
          .where('slot_status', isEqualTo: 'open')
          .get();

      if (!mounted) return;

      setState(() {
        _vendorProfile = vendorSnapshot.data();
        _openSlots = slotsSnapshot.docs;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Vendor application loading error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // SUBMIT APPLICATION
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an open booth slot.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in again.')));
      return;
    }

    final uid = user.uid;

    if (_vendorProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a vendor profile first.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final applicationId = '${widget.event.id}_$uid';

      final applicationRef = firestore
          .collection('applications')
          .doc(applicationId);

      await firestore.runTransaction((transaction) async {
        final existing = await transaction.get(applicationRef);

        if (existing.exists) {
          throw Exception('You have already applied to this event.');
        }

        final slotRef = firestore
            .collection('booth_slots')
            .doc(_selectedSlotId);

        final slot = await transaction.get(slotRef);

        if (!slot.exists || slot.data()?['slot_status'] != 'open') {
          throw Exception('Slot is no longer open.');
        }

        transaction.set(applicationRef, {
          'application_id': applicationId,
          'event_id': widget.event.id,
          'vendor_profile_id': uid,
          'vendor_name': _vendorProfile!['business_name'] as String? ?? '',
          'products_to_sell': _products.text.trim(),
          'booth_fee_amount': widget.event.boothFee,
          'requested_slot_id': _selectedSlotId,
          'application_status': 'pending',
          'rejection_reason': null,
          'applied_at': FieldValue.serverTimestamp(),
          'reviewed_at': null,
        });

        transaction.update(slotRef, {
          'slot_status': 'reserved',
          'reserved_application_id': applicationId,
          'reserved_at': FieldValue.serverTimestamp(),
        });
      });

      await firestore.collection('notifications').add({
        'recipient_user_id': uid,
        'related_event_id': widget.event.id,
        'related_application_id': applicationId,
        'notification_type': 'application',
        'title': 'Application submitted',
        'message': 'Your booth application is pending review.',
        'is_read': false,
        'read_at': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      await GiventsAnalyticsService.instance.applicationSubmitted(
        widget.event.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Application submission error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit application: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // LOADING SCREEN
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ERROR SCREEN
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Apply for a Slot')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Could not load application.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _vendorProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for a Slot')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.event.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 8),

            Text(
              '${widget.event.venueName}, '
              '${widget.event.city}, '
              '${widget.event.province}',
            ),

            const SizedBox(height: 16),

            TextFormField(
              initialValue: profile?['business_name'] as String? ?? '',
              decoration: const InputDecoration(labelText: 'Business name'),
              readOnly: true,
            ),

            const SizedBox(height: 12),

            TextFormField(
              initialValue: profile?['registration_id'] as String? ?? '',
              decoration: const InputDecoration(labelText: 'Registration ID'),
              readOnly: true,
            ),

            const SizedBox(height: 12),

            TextFormField(
              key: const Key('application_products'),
              controller: _products,
              decoration: const InputDecoration(
                labelText: 'Products to sell *',
              ),
              maxLines: 3,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: const Key('application_slot'),
              initialValue: _selectedSlotId,
              decoration: const InputDecoration(labelText: 'Open slot *'),
              items: _openSlots
                  .map(
                    (slot) => DropdownMenuItem(
                      value: slot.id,
                      child: Text(
                        slot.data()['slot_code'] as String? ?? slot.id,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSlotId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Select an open slot.' : null,
            ),

            if (_openSlots.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'No open booth slots available for this event.',
                style: TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 12),

            Text(
              'Booth fee: ₱${widget.event.boothFee.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting || _openSlots.isEmpty ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Submit application'),
            ),
          ],
        ),
      ),
    );
  }
}
