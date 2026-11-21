import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('organizer_profiles')
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Organizer profile not found'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrganizerProfileEditScreen(
                    profile: null,
                    onSaved: _loadProfile,
                  ),
                ),
              ),
              child: const Text('Create profile'),
            ),
          ],
        ),
      );
    }

    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 42,
          child: Text(
            (profile['organization_name'] as String? ?? 'O')
                .substring(0, 1)
                .toUpperCase(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile['organization_name'] as String? ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Center(
          child: Chip(
            label: Text(profile['organizer_type'] as String? ?? 'Organizer'),
          ),
        ),
        const SizedBox(height: 16),
        Text(profile['short_bio'] as String? ?? ''),
        const SizedBox(height: 16),
        _ProfileRow(label: 'Area', value: profile['area'] as String? ?? ''),
        _ProfileRow(
          label: 'Contact person',
          value: profile['contact_person'] as String? ?? '',
        ),
        _ProfileRow(label: 'Email', value: profile['email'] as String? ?? ''),
        _ProfileRow(
          label: 'Phone',
          value: profile['phone_number'] as String? ?? '',
        ),
        _ProfileRow(
          label: 'Address',
          value: profile['organizer_address'] as String? ?? '',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrganizerProfileEditScreen(
                profile: profile,
                onSaved: _loadProfile,
              ),
            ),
          ),
          child: const Text('Edit profile'),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class OrganizerProfileEditScreen extends StatefulWidget {
  const OrganizerProfileEditScreen({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final Map<String, dynamic>? profile;
  final Future<void> Function() onSaved;

  @override
  State<OrganizerProfileEditScreen> createState() =>
      _OrganizerProfileEditScreenState();
}

class _OrganizerProfileEditScreenState
    extends State<OrganizerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _organizationName;
  late final TextEditingController _organizerType;
  late final TextEditingController _shortBio;
  late final TextEditingController _area;
  late final TextEditingController _contactPerson;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _organizationName = TextEditingController(
      text: profile?['organization_name'] as String?,
    );
    _organizerType = TextEditingController(
      text: profile?['organizer_type'] as String?,
    );
    _shortBio = TextEditingController(text: profile?['short_bio'] as String?);
    _area = TextEditingController(text: profile?['area'] as String?);
    _contactPerson = TextEditingController(
      text: profile?['contact_person'] as String?,
    );
    _email = TextEditingController(text: profile?['email'] as String?);
    _phone = TextEditingController(text: profile?['phone_number'] as String?);
    _address = TextEditingController(
      text: profile?['organizer_address'] as String?,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _organizationName,
      _organizerType,
      _shortBio,
      _area,
      _contactPerson,
      _email,
      _phone,
      _address,
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
          .collection('organizer_profiles')
          .doc(uid)
          .set({
            'organizer_profile_id': uid,
            'organization_name': _organizationName.text.trim(),
            'organizer_type': _organizerType.text.trim(),
            'short_bio': _shortBio.text.trim(),
            'area': _area.text.trim(),
            'contact_person': _contactPerson.text.trim(),
            'email': _email.text.trim(),
            'phone_number': _phone.text.trim(),
            'organizer_address': _address.text.trim(),
            'created_at': widget.profile == null
                ? FieldValue.serverTimestamp()
                : null,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save profile.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit organizer profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _organizationName,
              decoration: const InputDecoration(labelText: 'Organization name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _organizerType,
              decoration: const InputDecoration(labelText: 'Organizer type'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortBio,
              decoration: const InputDecoration(labelText: 'Short bio'),
              maxLines: 3,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(labelText: 'Area'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPerson,
              decoration: const InputDecoration(labelText: 'Contact person'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Organizer address'),
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
