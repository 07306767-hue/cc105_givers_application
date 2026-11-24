import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const legazpiMapCenter = LatLng(13.1391, 123.7438);

class OsmMapMarker {
  const OsmMapMarker({required this.point, required this.label, this.onTap});

  final LatLng point;
  final String label;
  final VoidCallback? onTap;
}

class OpenStreetMapView extends StatelessWidget {
  const OpenStreetMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13,
    this.markers = const [],
    this.onMapTap,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final List<OsmMapMarker> markers;
  final ValueChanged<LatLng>? onMapTap;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: (_, point) => onMapTap?.call(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.cc105_givers_documentation',
        ),
        MarkerLayer(
          markers: markers
              .map(
                (marker) => Marker(
                  point: marker.point,
                  width: 44,
                  height: 48,
                  child: GestureDetector(
                    onTap: marker.onTap,
                    child: Tooltip(
                      message: marker.label,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
