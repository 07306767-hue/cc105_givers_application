import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_shell.dart';
import '../maps/open_street_map_view.dart';
import '../vendor/vendor_application_screen.dart';
import '../services/givents_services.dart';
import 'events_map_screen.dart';
import 'event_models.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event, required this.role});

  final GiventsEvent event;
  final GiventsRole role;

  String _formatDate() {
    final date = event.date.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<int> _openSlotCount() async {
    final result = await FirebaseFirestore.instance
        .collection('booth_slots')
        .where('event_id', isEqualTo: event.id)
        .where('slot_status', isEqualTo: 'open')
        .count()
        .get();
    return result.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    final hasLocation =
        latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (event.eventPhotoUrl != null &&
              event.eventPhotoUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                event.eventPhotoUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Chip(label: Text(event.category)),
          const SizedBox(height: 8),
          Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${_formatDate()}  •  ${event.startTime}–${event.endTime}'),
          const Text('Philippine time'),
          const SizedBox(height: 16),
          Text(event.description),
          const SizedBox(height: 24),
          Text('VENDOR SLOTS', style: Theme.of(context).textTheme.titleSmall),
          FutureBuilder<int>(
            future: _openSlotCount(),
            builder: (context, snapshot) {
              final open = snapshot.data ?? 0;
              return Text('$open slots open');
            },
          ),
          const SizedBox(height: 12),
          Text('BOOTH FEE', style: Theme.of(context).textTheme.titleSmall),
          Text('₱${event.boothFee.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          const Text('Location'),
          Text(
            '${event.venueName}, ${event.venueAddress}, ${event.city}, ${event.province}',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: OpenStreetMapView(
                initialCenter: hasLocation
                    ? LatLng(latitude, longitude)
                    : legazpiMapCenter,
                initialZoom: hasLocation ? 15 : 12,
                markers: hasLocation
                    ? [
                        OsmMapMarker(
                          point: LatLng(latitude, longitude),
                          label: event.title,
                        ),
                      ]
                    : const [],
              ),
            ),
          ),
          if (!hasLocation) ...[
            const SizedBox(height: 8),
            const Text('The organiser has not pinned this event location yet.'),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EventsMapScreen(role: role)),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open map view'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ORGANIZED BY'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    OrganizerProfilePlaceholder(organizerId: event.organizerId),
              ),
            ),
            child: const Text('View organizer profile'),
          ),
        ],
      ),
      bottomNavigationBar: role == GiventsRole.vendor
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () async {
                    await GiventsAnalyticsService.instance.applySlotTapped(
                      event.id,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VendorApplicationScreen(event: event),
                      ),
                    );
                  },
                  child: Text(
                    'Apply for a slot  •  ₱${event.boothFee.toStringAsFixed(0)} per booth',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class OrganizerProfilePlaceholder extends StatelessWidget {
  const OrganizerProfilePlaceholder({super.key, required this.organizerId});

  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('organizer_profiles')
            .doc(organizerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Organizer profile unavailable'));
          }
          final data = snapshot.data!.data()!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data['organization_name'] as String? ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(data['organizer_type'] as String? ?? 'Organizer'),
              ),
              const SizedBox(height: 12),
              Text(data['short_bio'] as String? ?? ''),
              const SizedBox(height: 12),
              Text('Area: ${data['area'] ?? ''}'),
              Text('Contact: ${data['contact_person'] ?? ''}'),
              Text('Email: ${data['email'] ?? ''}'),
              Text('Phone: ${data['phone_number'] ?? ''}'),
            ],
          );
        },
      ),
    );
  }
}
