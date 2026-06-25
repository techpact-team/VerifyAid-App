import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../auth/current_profile_service.dart';
import 'distribution_service.dart';

class DistributionSearchScreen extends StatefulWidget {
  const DistributionSearchScreen({super.key});

  @override
  State<DistributionSearchScreen> createState() =>
      _DistributionSearchScreenState();
}

class _DistributionSearchScreenState extends State<DistributionSearchScreen> {
  final searchController = TextEditingController();
  final service = DistributionService();
  final profileService = CurrentProfileService();

  bool loading = false;
  List<Map<String, dynamic>> results = [];

  String _beneficiaryValue(
    Map<String, dynamic> beneficiary,
    String key, {
    String fallback = 'N/A',
  }) {
    return fieldDisplayValue(beneficiary[key], fallback: fallback);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    setState(() {
      loading = true;
    });

    try {
      final profile = await profileService.getCurrentProfile();
      final tenantId = profile?['tenant_id']?.toString();
      final locationId = profile?['location_id']?.toString();

      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('No tenant assigned to current user.');
      }
      if (locationId == null || locationId.isEmpty) {
        throw Exception('No location assigned to current user.');
      }

      final data = await service.searchBeneficiaries(
        query: searchController.text,
        tenantId: tenantId,
        locationId: locationId,
      );

      if (!mounted) return;

      setState(() {
        results = data;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Distribution search failed: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Check logs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distribution Search')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: loading ? null : search,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (loading) const LinearProgressIndicator(),

              if (loading) const SizedBox(height: 12),

              if (results.isNotEmpty) ...[
                Text(
                  'Search results (${results.length})',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Expanded(
                child: results.isEmpty
                    ? ListView(
                        children: const [
                          FieldSurface(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_search,
                                  color: AppColors.muted,
                                  size: 42,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Search for a registered beneficiary.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final beneficiary = results[index];
                          return _buildBeneficiaryResult(beneficiary);
                        },
                      ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Can't find the beneficiary?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/beneficiaries/register'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Register New Beneficiary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryResult(Map<String, dynamic> beneficiary) {
    final name = _beneficiaryValue(
      beneficiary,
      'full_name',
      fallback: 'Unnamed Beneficiary',
    );
    final status = fieldDisplayValue(
      beneficiary['status'],
      fallback: 'Registered',
    );

    return FieldSurface(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FieldPhotoAvatar(label: name, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FieldStatusPill(
                      label: status,
                      icon: Icons.check,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'ID: ${_beneficiaryValue(beneficiary, 'national_id')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phone: ${_beneficiaryValue(beneficiary, 'phone')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                context.push('/distribution/verify', extra: beneficiary);
              },
              child: const Text('Verify'),
            ),
          ),
        ],
      ),
    );
  }
}
