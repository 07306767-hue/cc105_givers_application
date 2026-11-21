import 'package:cloud_firestore/cloud_firestore.dart';

class GiventsEvent {
  GiventsEvent({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.venueName,
    required this.venueAddress,
    required this.city,
    required this.province,
    required this.totalSlots,
    required this.boothFee,
  });

  factory GiventsEvent.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return GiventsEvent(
      id: snapshot.id,
      organizerId: data['organizer_profile_id'] as String,
      title: data['event_title'] as String? ?? '',
      category: data['event_category'] as String? ?? 'Fair',
      description: data['event_description'] as String? ?? '',
      date: data['event_date'] as Timestamp,
      startTime: data['start_time'] as String? ?? '',
      endTime: data['end_time'] as String? ?? '',
      venueName: data['venue_name'] as String? ?? '',
      venueAddress: data['venue_address'] as String? ?? '',
      city: data['city'] as String? ?? '',
      province: data['province'] as String? ?? '',
      totalSlots: (data['total_slots'] as num).toInt(),
      boothFee: (data['booth_fee'] as num).toDouble(),
    );
  }

  final String id;
  final String organizerId;
  final String title;
  final String category;
  final String description;
  final Timestamp date;
  final String startTime;
  final String endTime;
  final String venueName;
  final String venueAddress;
  final String city;
  final String province;
  final int totalSlots;
  final double boothFee;
}
