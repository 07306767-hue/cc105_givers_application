import 'package:flutter/material.dart';

import 'attendee/calendar_screen.dart';
import 'organizer/organizer_overview_screen.dart';
import 'vendor/vendor_home_screen.dart';
import 'auth/auth_service.dart';
import 'attendee/events_screen.dart';
import 'organizer/create_event_screen.dart';
import 'organizer/event_intake_draft_screen.dart';
import 'organizer/organizer_events_placeholder.dart';
import 'organizer/organizer_profile_screen.dart';
import 'vendor/vendor_profile_screen.dart';
import 'organizer/application_review_screen.dart';
import 'vendor/vendor_payments_screen.dart';
import 'notifications/notifications_screen.dart';
import 'lost_found/lost_found_screen.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum GiventsRole { attendee, organizer, vendor }

class RoleBasedAppShell extends StatefulWidget {
  const RoleBasedAppShell({super.key, this.role = GiventsRole.attendee});

  final GiventsRole role;

  @override
  State<RoleBasedAppShell> createState() => _RoleBasedAppShellState();
}

class _RoleBasedAppShellState extends State<RoleBasedAppShell> {
  int _index = 0;

  static const _labels = <GiventsRole, List<String>>{
    GiventsRole.attendee: ['Home', 'Calendar', 'Map', 'Account'],
    GiventsRole.organizer: ['Overview', 'Events', 'Applications', 'Account'],
    GiventsRole.vendor: ['Home', 'Discover', 'Applications', 'Profile'],
  };

  static const _icons = <GiventsRole, List<IconData>>{
    GiventsRole.attendee: [
      Icons.home_outlined,
      Icons.calendar_today_outlined,
      Icons.map_outlined,
      Icons.person_outline,
    ],
    GiventsRole.organizer: [
      Icons.dashboard_outlined,
      Icons.event_outlined,
      Icons.assignment_outlined,
      Icons.person_outline,
    ],
    GiventsRole.vendor: [
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.assignment_outlined,
      Icons.storefront_outlined,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final labels = _labels[widget.role]!;
    final icons = _icons[widget.role]!;
    final safeIndex = _index.clamp(0, labels.length - 1).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(labels[safeIndex]),
        actions: [
          if (kDebugMode && !kIsWeb)
            IconButton(
              tooltip: 'Test crash',
              onPressed: () => FirebaseCrashlytics.instance.crash(),
              icon: const Icon(Icons.bug_report_outlined),
            ),
        ],
      ),
      body: widget.role == GiventsRole.attendee && safeIndex == 0
          ? LostFoundAwareEvents(role: widget.role)
          : widget.role == GiventsRole.attendee && safeIndex == 1
          ? const CalendarScreen()
          : widget.role == GiventsRole.attendee && safeIndex == 3
          ? const NotificationsScreen()
          : widget.role == GiventsRole.organizer && safeIndex == 0
          ? const OrganizerOverviewScreen()
          : widget.role == GiventsRole.organizer && safeIndex == 1
          ? OrganizerEventsPlaceholder(
              onCreate: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
              },
              onDraft: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EventIntakeDraftScreen(),
                  ),
                );
              },
            )
          : widget.role == GiventsRole.organizer && safeIndex == 3
          ? const OrganizerProfileScreen()
          : widget.role == GiventsRole.organizer && safeIndex == 2
          ? const OrganizerApplicationsScreen()
          : widget.role == GiventsRole.vendor && safeIndex == 0
          ? const VendorHomeScreen()
          : widget.role == GiventsRole.vendor && safeIndex == 1
          ? const EventsScreen(role: GiventsRole.vendor)
          : widget.role == GiventsRole.vendor && safeIndex == 3
          ? const VendorProfileScreen()
          : widget.role == GiventsRole.vendor && safeIndex == 2
          ? const VendorPaymentsScreen()
          : Center(
              child: Text(
                '${labels[safeIndex]} (ASSUMPTION placeholder)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
      floatingActionButton: safeIndex == labels.length - 1
          ? FloatingActionButton.small(
              tooltip: 'Sign out',
              onPressed: () async {
                await GiventsAuthService().signOut();
              },
              child: const Icon(Icons.logout),
            )
          : null,
    );
  }
}

class LostFoundAwareEvents extends StatelessWidget {
  const LostFoundAwareEvents({super.key, required this.role});

  final GiventsRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LostFoundScreen())),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Lost and Found'),
          ),
        ),
        Expanded(child: EventsScreen(role: role)),
      ],
    );
  }
}
