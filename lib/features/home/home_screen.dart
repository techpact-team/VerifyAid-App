import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../auth/current_profile_service.dart';
import '../sync/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final profileService = CurrentProfileService();
  final syncService = SyncService();

  Map<String, dynamic>? profile;
  bool loading = true;
  bool syncing = false;
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
    if (syncing) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      syncing = true;
    });

    try {
      final result = await syncService.syncOfflineData();

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(SnackBar(content: Text(result.summary)));
    } catch (e) {
      debugPrint('Home sync failed: $e');

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Sync failed. Check logs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          syncing = false;
        });
      }
    }
  }

  String _profileValue(String key, {String fallback = 'N/A'}) {
    return fieldDisplayValue(profile?[key], fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VerifyAid')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FieldSurface(
                color: AppColors.dangerSoft,
                borderColor: AppColors.danger.withValues(alpha: 0.24),
                child: Text(
                  'Failed to load profile:\n\n$error',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VerifyAid')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: FieldSurface(
              child: Text(
                'Login successful, but no profile row was found for this user.\n\nCreate a matching row in the profiles table where profiles.id = auth.users.id.',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              FieldSurface(
                padding: const EdgeInsets.all(18),
                color: AppColors.surface,
                borderColor: AppColors.primary.withValues(alpha: 0.12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FieldPhotoAvatar(
                      label: _profileValue('full_name', fallback: 'VA'),
                      size: 64,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profileValue(
                              'full_name',
                              fallback: 'Field Officer',
                            ),
                            softWrap: true,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 24,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Field Officer',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FieldStatusPill(
                                label: _profileValue(
                                  'status',
                                  fallback: 'Online',
                                ),
                                icon: Icons.wifi,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _HomeActionTile(
                icon: Icons.person_add_alt_1,
                title: 'Register Beneficiary',
                subtitle: 'Add a person and capture their details.',
                color: AppColors.primary,
                onTap: () => context.go('/beneficiaries/register'),
              ),
              const SizedBox(height: 10),
              _HomeActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Start Distribution',
                subtitle: 'Find a beneficiary and record support.',
                color: AppColors.primaryBright,
                onTap: () => context.go('/distribution'),
              ),
              const SizedBox(height: 10),
              _HomeActionTile(
                icon: Icons.fingerprint,
                title: 'Device Configuration',
                subtitle: 'Set up the SecuGen fingerprint scanner.',
                color: AppColors.info,
                onTap: () => context.go('/devices/config'),
              ),
              const SizedBox(height: 10),
              _HomeActionTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Sync Offline Data',
                subtitle: 'Upload saved work when you have a connection.',
                color: AppColors.amber,
                onTap: syncing ? null : syncOfflineData,
                busy: syncing,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FieldBottomNav(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 1:
              context.go('/beneficiaries/register');
              break;
            case 2:
              context.go('/distribution');
              break;
            case 3:
              context.go('/sync');
              break;
          }
        },
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: busy
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 25),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
