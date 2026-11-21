import 'package:flutter/material.dart';

class OrganizerEventsPlaceholder extends StatelessWidget {
  const OrganizerEventsPlaceholder({
    super.key,
    required this.onCreate,
    required this.onDraft,
  });

  final VoidCallback onCreate;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: onCreate, child: const Text('Create event')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onDraft, child: const Text('Draft event')),
      ],
    );
  }
}
