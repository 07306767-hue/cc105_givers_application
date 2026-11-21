import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  Map<String, dynamic>? _profile;
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
        .collection('vendor_profiles')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _profile = snapshot.data();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null) {
      return Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  VendorProfileEditScreen(profile: null, onSaved: _load),
            ),
          ),
          child: const Text('Create vendor profile'),
        ),
      );
    }

    final profile = _profile!;
    final status = profile['verification_status'] as String? ?? 'pending';
    final bannerColor = status == 'verified'
        ? Colors.green
        : status == 'not_verified'
        ? Colors.red
        : Colors.orange;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Verification: ${status.replaceAll('_', ' ')}',
            style: TextStyle(color: bannerColor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile['business_name'] as String? ?? '',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text('Owner: ${profile['owner_name'] ?? ''}'),
        Text('Product category: ${profile['product_category'] ?? ''}'),
        Text('Description: ${profile['product_description'] ?? ''}'),
        Text('Registration ID: ${profile['registration_id'] ?? ''}'),
        Text('Contact: ${profile['masked_contact'] ?? ''}'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  VendorProfileEditScreen(profile: profile, onSaved: _load),
            ),
          ),
          child: const Text('Edit business details'),
        ),
      ],
    );
  }
}

class VendorProfileEditScreen extends StatefulWidget {
  const VendorProfileEditScreen({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final Map<String, dynamic>? profile;
  final Future<void> Function() onSaved;

  @override
  State<VendorProfileEditScreen> createState() =>
      _VendorProfileEditScreenState();
}

class _VendorProfileEditScreenState extends State<VendorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessName;
  late final TextEditingController _ownerName;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _registrationId;
  late final TextEditingController _maskedContact;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _businessName = TextEditingController(
      text: profile?['business_name'] as String?,
    );
    _ownerName = TextEditingController(text: profile?['owner_name'] as String?);
    _category = TextEditingController(
      text: profile?['product_category'] as String?,
    );
    _description = TextEditingController(
      text: profile?['product_description'] as String?,
    );
    _registrationId = TextEditingController(
      text: profile?['registration_id'] as String?,
    );
    _maskedContact = TextEditingController(
      text: profile?['masked_contact'] as String?,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _businessName,
      _ownerName,
      _category,
      _description,
      _registrationId,
      _maskedContact,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('vendor_profiles')
          .doc(uid)
          .set({
            'vendor_profile_id': uid,
            'business_name': _businessName.text.trim(),
            'owner_name': _ownerName.text.trim(),
            'product_category': _category.text.trim(),
            'product_description': _description.text.trim(),
            'registration_id': _registrationId.text.trim(),
            'masked_contact': _maskedContact.text.trim(),
            'verification_status':
                widget.profile?['verification_status'] as String? ?? 'pending',
            'created_at': widget.profile == null
                ? FieldValue.serverTimestamp()
                : null,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit business details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _businessName,
              decoration: const InputDecoration(labelText: 'Business name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerName,
              decoration: const InputDecoration(labelText: 'Owner name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Product category'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Product description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registrationId,
              decoration: const InputDecoration(labelText: 'Registration ID'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maskedContact,
              decoration: const InputDecoration(
                labelText: 'Masked contact number',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
