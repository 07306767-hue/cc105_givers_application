import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/cloudinary_image_service.dart';
import 'event_location_picker_screen.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please log in again.'));
    }

    final eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('organizer_profile_id', isEqualTo: uid)
        .where('event_status', isEqualTo: 'published')
        .orderBy('event_date');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: onCreate, child: const Text('Create event')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onDraft, child: const Text('Draft event')),
        const SizedBox(height: 24),

        Text(
          'My Published Events',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Could not load events: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data?.docs ?? [];

            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('You have no published events yet.')),
              );
            }

            return Column(
              children: events.map((event) {
                final data = event.data();
                final title =
                    data['event_title'] as String? ?? 'Untitled event';
                final venue =
                    data['venue_name'] as String? ?? 'No venue provided';
                final date = data['event_date'] as Timestamp?;

                return _OrganizerPublishedEventCard(
                  key: ValueKey(event.id),
                  eventId: event.id,
                  title: title,
                  venue: venue,
                  dateLabel: date == null
                      ? 'Date not set'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(date.toDate()),
                  photoUrl: data['event_photo_url'] as String?,
                  latitude: (data['latitude'] as num?)?.toDouble(),
                  longitude: (data['longitude'] as num?)?.toDouble(),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _OrganizerPublishedEventCard extends StatefulWidget {
  const _OrganizerPublishedEventCard({
    super.key,
    required this.eventId,
    required this.title,
    required this.venue,
    required this.dateLabel,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
  });

  final String eventId;
  final String title;
  final String venue;
  final String dateLabel;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;

  @override
  State<_OrganizerPublishedEventCard> createState() =>
      _OrganizerPublishedEventCardState();
}

class _OrganizerPublishedEventCardState
    extends State<_OrganizerPublishedEventCard> {
  String? _photoUrl;
  double? _latitude;
  double? _longitude;
  bool _uploading = false;
  bool _pinning = false;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.photoUrl;
    _latitude = widget.latitude;
    _longitude = widget.longitude;
  }

  @override
  void didUpdateWidget(covariant _OrganizerPublishedEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _photoUrl = widget.photoUrl;
    }
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _latitude = widget.latitude;
      _longitude = widget.longitude;
    }
  }

  Future<void> _uploadPhoto() async {
    setState(() => _uploading = true);
    try {
      final url = await CloudinaryImageService().pickAndUploadImage();
      if (url == null || !mounted) return;

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'event_photo_url': url});

      if (!mounted) return;
      setState(() => _photoUrl = url);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event photo saved.')));
    } catch (error) {
      debugPrint('Published event photo upload error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save event photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pinLocation() async {
    final initialPosition = _latitude == null || _longitude == null
        ? null
        : LatLng(_latitude!, _longitude!);
    final position = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            EventLocationPickerScreen(initialPosition: initialPosition),
      ),
    );
    if (position == null || !mounted) return;

    setState(() => _pinning = true);
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event location saved.')));
    } catch (error) {
      debugPrint('Published event location update error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save event location: $error')),
      );
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _photoUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: SizedBox(
          width: 64,
          height: 64,
          child: photoUrl != null && photoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                )
              : const Icon(Icons.event),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${widget.venue}\n${widget.dateLabel}\nPublished'),
        isThreeLine: true,
        trailing: _uploading || _pinning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: photoUrl != null && photoUrl.isNotEmpty
                        ? 'Change event photo'
                        : 'Add event photo',
                    onPressed: _uploadPhoto,
                    icon: Icon(
                      photoUrl != null && photoUrl.isNotEmpty
                          ? Icons.edit_outlined
                          : Icons.add_photo_alternate_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: _latitude != null && _longitude != null
                        ? 'Change event location'
                        : 'Pin event location',
                    onPressed: _pinLocation,
                    icon: Icon(
                      _latitude != null && _longitude != null
                          ? Icons.edit_location_alt_outlined
                          : Icons.add_location_alt_outlined,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
