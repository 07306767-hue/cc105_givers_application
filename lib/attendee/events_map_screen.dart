import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_shell.dart';
import '../maps/open_street_map_view.dart';
import 'event_detail_screen.dart';
import 'event_models.dart';

class EventsMapScreen extends StatelessWidget {
  const EventsMapScreen({super.key, required this.role});

  final GiventsRole role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map view')),
      body: EventsMapContent(role: role),
    );
  }
}

class EventsMapContent extends StatelessWidget {
  const EventsMapContent({super.key, required this.role});

  final GiventsRole role;

  @override
  Widget build(BuildContext context) {
    final eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('event_status', isEqualTo: 'published');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: eventsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load event locations: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events =
            snapshot.data?.docs.map(GiventsEvent.fromSnapshot).toList() ?? [];
        final locatedEvents = events.where(_hasCoordinates).toList();
        final markers = locatedEvents
            .map(
              (event) => OsmMapMarker(
                point: LatLng(event.latitude!, event.longitude!),
                label: event.title,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: event, role: role),
                  ),
                ),
              ),
            )
            .toList();

        return Stack(
          children: [
            OpenStreetMapView(
              initialCenter: markers.isEmpty
                  ? legazpiMapCenter
                  : markers.first.point,
              initialZoom: markers.isEmpty ? 12 : 10,
              markers: markers,
            ),
            if (locatedEvents.isEmpty)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        events.isEmpty
                            ? 'No published events yet.'
                            : 'No event locations pinned yet.',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _hasCoordinates(GiventsEvent event) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
