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
  int pendingSyncCount = 0;
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

      await loadPendingSyncCount();
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
      final pendingCount = await syncService.pendingCount();

      if (!mounted) return;

      setState(() {
        pendingSyncCount = pendingCount;
      });

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

  Future<void> loadPendingSyncCount() async {
    try {
      final count = await syncService.pendingCount();

      if (!mounted) return;

      setState(() {
        pendingSyncCount = count;
      });
    } catch (_) {
      // Sync count is informational and should not block Home.
    }
  }

  String _profileValue(String key, {String fallback = 'N/A'}) {
    return fieldDisplayValue(profile?[key], fallback: fallback);
  }

  String _profileFirst(List<String> keys, {String fallback = 'N/A'}) {
    for (final key in keys) {
      final value = profile?[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              FieldSurface(
                color: const Color(0xFFF1FAF7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldPhotoAvatar(
                          label: _profileValue('full_name', fallback: 'VA'),
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _profileValue(
                                  'full_name',
                                  fallback: 'Field Officer',
                                ),
                                softWrap: true,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Field Officer',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_none,
                            color: AppColors.text,
                          ),
                        ),
                        FieldStatusPill(
                          label: _profileValue('status', fallback: 'Online'),
                          icon: Icons.wifi,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    FieldInfoRow(
                      icon: Icons.apartment,
                      label: 'Organization',
                      value: _profileFirst([
                        'organization_name',
                        'tenant_name',
                        'tenant_id',
                      ], fallback: 'Assigned organization'),
                    ),
                    const SizedBox(height: 12),
                    FieldInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: _profileFirst([
                        'location_name',
                        'location_id',
                      ], fallback: 'Assigned location'),
                    ),
                    const SizedBox(height: 12),
                    FieldInfoRow(
                      icon: Icons.sync,
                      label: 'Offline Sync',
                      value: pendingSyncCount == 0
                          ? 'All caught up'
                          : '$pendingSyncCount pending records',
                      iconColor: pendingSyncCount == 0
                          ? AppColors.primary
                          : AppColors.amber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DashboardActionCard(
                      icon: Icons.person_add_alt_1,
                      title: 'Register\nBeneficiary',
                      color: AppColors.primary,
                      onTap: () => context.go('/beneficiaries/register'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardActionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Start\nDistribution',
                      color: AppColors.info,
                      onTap: () => context.go('/distribution'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardActionCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Sync Offline\nData',
                      color: const Color(0xFF6C5CE7),
                      onTap: syncing ? null : syncOfflineData,
                      busy: syncing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Today\'s Overview',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: _OverviewCard(
                      label: 'Registered\nToday',
                      value: '0',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OverviewCard(
                      label: 'Pending\nSync',
                      value: pendingSyncCount.toString(),
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: _OverviewCard(
                      label: 'Distributions\nCompleted',
                      value: '0',
                      color: AppColors.info,
                    ),
                  ),
                ],
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

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FieldSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 92,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FieldSurface(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height: 70,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
