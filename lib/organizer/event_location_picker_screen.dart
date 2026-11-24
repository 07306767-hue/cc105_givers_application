import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../maps/open_street_map_view.dart';

class EventLocationPickerScreen extends StatefulWidget {
  const EventLocationPickerScreen({super.key, this.initialPosition});

  final LatLng? initialPosition;

  @override
  State<EventLocationPickerScreen> createState() =>
      _EventLocationPickerScreenState();
}

class _EventLocationPickerScreenState extends State<EventLocationPickerScreen> {
  late LatLng? _selectedPosition = widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPosition;

    return Scaffold(
      appBar: AppBar(title: const Text('Pin event location')),
      body: Stack(
        children: [
          OpenStreetMapView(
            initialCenter: selectedPosition ?? legazpiMapCenter,
            initialZoom: selectedPosition == null ? 12 : 15,
            markers: selectedPosition == null
                ? const []
                : [
                    OsmMapMarker(
                      point: selectedPosition,
                      label: 'Event location',
                    ),
                  ],
            onMapTap: (point) => setState(() => _selectedPosition = point),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  selectedPosition == null
                      ? 'Tap the map to pin your event venue.'
                      : 'Pinned: ${selectedPosition.latitude.toStringAsFixed(5)}, '
                            '${selectedPosition.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton(
                onPressed: selectedPosition == null
                    ? null
                    : () => Navigator.of(context).pop(selectedPosition),
                child: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
