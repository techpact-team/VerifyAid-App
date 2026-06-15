import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/current_profile_service.dart';
import '../sync/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final profileService = CurrentProfileService();

  Map<String, dynamic>? profile;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final data = await profileService.getCurrentProfile();

      if (!mounted) return;

      setState(() {
        profile = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> syncOfflineData() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final count = await SyncService().syncPendingBeneficiaries();

    if (!mounted) return;

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Synced $count beneficiaries')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VerifyAid')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load profile:\n\n$error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VerifyAid')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Login successful, but no profile row was found for this user.\n\nCreate a matching row in the profiles table where profiles.id = auth.users.id.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('VerifyAid Field Operations')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${profile?['full_name'] ?? 'Officer'}'),
            Text('Email: ${profile?['email'] ?? 'N/A'}'),
            Text('Tenant ID: ${profile?['tenant_id'] ?? 'N/A'}'),
            Text('Location ID: ${profile?['location_id'] ?? 'N/A'}'),
            Text('Status: ${profile?['status'] ?? 'N/A'}'),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => context.go('/beneficiaries/register'),
              child: const Text('Register Beneficiary'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () => context.go('/distribution'),
              child: const Text('Start Distribution'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: syncOfflineData,
              child: const Text('Sync Offline Data'),
            ),
          ],
        ),
      ),
    );
  }
}
