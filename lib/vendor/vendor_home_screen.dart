import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  bool _loading = true;
  String? _error;

  int _totalApplications = 0;
  int _pendingApplications = 0;
  int _approvedApplications = 0;
  int _rejectedApplications = 0;
  int _successfulPayments = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in account found.');
      }

      final firestore = FirebaseFirestore.instance;

      final applications = await firestore
          .collection('applications')
          .where('vendor_profile_id', isEqualTo: user.uid)
          .get();

      final payments = await firestore
          .collection('payments')
          .where('vendor_profile_id', isEqualTo: user.uid)
          .get();

      final applicationData = applications.docs.map((doc) => doc.data());

      final pending = applicationData
          .where((data) => data['application_status'] == 'pending')
          .length;

      final approved = applicationData
          .where((data) => data['application_status'] == 'approved')
          .length;

      final rejected = applicationData
          .where((data) => data['application_status'] == 'rejected')
          .length;

      final paid = payments.docs
          .where((doc) => doc.data()['payment_status'] == 'paid')
          .length;

      if (!mounted) return;

      setState(() {
        _totalApplications = applications.docs.length;
        _pendingApplications = pending;
        _approvedApplications = approved;
        _rejectedApplications = rejected;
        _successfulPayments = paid;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Vendor dashboard error: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _summaryCard(String title, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 45, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Could not load dashboard.'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome to Givents!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('Here is an overview of your vendor activity.'),
          const SizedBox(height: 20),

          Text(
            'Application Overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              _summaryCard(
                'Total Applications',
                _totalApplications,
                Icons.assignment_outlined,
              ),
              _summaryCard(
                'Pending',
                _pendingApplications,
                Icons.pending_actions,
              ),
              _summaryCard(
                'Approved',
                _approvedApplications,
                Icons.check_circle_outline,
              ),
              _summaryCard(
                'Rejected',
                _rejectedApplications,
                Icons.cancel_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Payment Overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          _summaryCard(
            'Successful Payments',
            _successfulPayments,
            Icons.payments_outlined,
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Dashboard'),
          ),
        ],
      ),
    );
  }
}
