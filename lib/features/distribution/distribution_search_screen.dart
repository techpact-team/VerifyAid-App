import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  Map<String, dynamic>? profile;
  bool profileLoading = true;
  String? profileError;

  bool loading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> results = [];

  bool _qrProcessing = false;

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
        profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        profileError = e.toString();
        profileLoading = false;
      });
    }
  }

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
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Cannot search.')),
      );
      return;
    }

    setState(() {
      loading = true;
      _hasSearched = true;
    });

    try {
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

  void _navigateToVerify(Map<String, dynamic> beneficiary, String lookupMethod) {
    context.push('/distribution/verify', extra: {
      'beneficiary': beneficiary,
      'lookupMethod': lookupMethod,
    });
  }

  Future<void> _openQrScanner() async {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Cannot scan.')),
      );
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const _QrScannerPage(),
      ),
    );

    if (result == null || !mounted) return;
    await _processQrCode(result);
  }

  Future<void> _processQrCode(String rawData) async {
    if (_qrProcessing) return;

    setState(() {
      _qrProcessing = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final Map<String, dynamic> qrPayload;
      try {
        qrPayload = Map<String, dynamic>.from(
          jsonDecode(rawData) as Map,
        );
      } catch (_) {
        throw Exception('Invalid QR code format. Expected JSON payload.');
      }

      final beneficiaryId = qrPayload['beneficiary_id']?.toString();
      final qrTenantId = qrPayload['tenant_id']?.toString();

      if (beneficiaryId == null || beneficiaryId.isEmpty) {
        throw Exception('QR code missing beneficiary_id.');
      }

      final tenantId = profile?['tenant_id']?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('No tenant assigned to current user.');
      }

      // Validate tenant match if QR includes tenant_id
      if (qrTenantId != null && qrTenantId.isNotEmpty && qrTenantId != tenantId) {
        throw Exception('QR code belongs to a different organization.');
      }

      final beneficiary = await service.fetchBeneficiaryById(
        beneficiaryId: beneficiaryId,
        tenantId: tenantId,
      );

      if (!mounted) return;

      if (beneficiary == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Beneficiary not found for this QR code.')),
        );
        return;
      }

      _navigateToVerify(beneficiary, 'qr');
    } catch (e) {
      debugPrint('QR processing failed: $e');

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _qrProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (profileLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: const FieldBackButton(),
          title: const Text('Start Distribution'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (profileError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: const FieldBackButton(),
          title: const Text('Start Distribution'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FieldSurface(
              color: AppColors.dangerSoft,
              borderColor: AppColors.danger.withValues(alpha: 0.24),
              child: Text(
                'Failed to load profile:\n\n$profileError',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const FieldBackButton(),
          title: const Text('Start Distribution'),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: FieldSurface(
              child: Text(
                'No profile row was found for this user. Please ensure a profile is set up in Supabase.',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: const FieldBackButton(),
        title: const Text('Start Distribution'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search bar hero ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or national ID…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: search,
                              tooltip: 'Search',
                            ),
                      filled: true,
                      fillColor: AppColors.canvas,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _qrProcessing ? null : _openQrScanner,
                      icon: _qrProcessing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: Text(
                        _qrProcessing
                            ? 'Processing QR…'
                            : 'Scan QR Code',
                      ),
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),

            // ── Results label ─────────────────────────────────────────────
            if (results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${results.length} beneficiar${results.length == 1 ? 'y' : 'ies'} found',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Results list / empty state ────────────────────────────────
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final beneficiary = results[index];
                        return _buildBeneficiaryResult(beneficiary);
                      },
                    ),
            ),

            // ── Register CTA ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Can't find the beneficiary?",
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_hasSearched && !loading && results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FieldSurface(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No beneficiary found',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No match for "${searchController.text}". Check the spelling or try a different ID or phone number.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Initial / idle state
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        FieldSurface(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              _SearchHeroIllustration(),
              SizedBox(height: 16),
              Text(
                'Find a Beneficiary',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Type a name, phone number or national ID above, or scan a QR code to begin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficiaryResult(Map<String, dynamic> beneficiary) {
    final name = _beneficiaryValue(
      beneficiary,
      'full_name',
      fallback: 'Unnamed Beneficiary',
    );
    final nationalId = _beneficiaryValue(beneficiary, 'national_id');
    final phone = _beneficiaryValue(beneficiary, 'phone');
    final status = fieldDisplayValue(
      beneficiary['status'],
      fallback: 'Registered',
    );

    return FieldSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FieldPhotoAvatar(label: name, size: 52),
          const SizedBox(width: 12),
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
                      icon: Icons.verified_outlined,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 12,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      nationalId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 12,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                _navigateToVerify(beneficiary, 'search');
              },
              icon: const Icon(Icons.verified_user_outlined, size: 16),
              label: const Text('Verify'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple decorative illustration for the idle search state.
class _SearchHeroIllustration extends StatelessWidget {
  const _SearchHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const Icon(Icons.person_search, color: AppColors.primary, size: 42),
      ],
    );
  }
}

/// Full-screen QR scanner page.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _hasReturned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasReturned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _hasReturned = true;
    Navigator.of(context).pop(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with scan area indicator
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Point the camera at a beneficiary QR code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
