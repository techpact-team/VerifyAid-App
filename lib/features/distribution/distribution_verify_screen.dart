import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../biometrics/biometric_service.dart';
import 'distribution_service.dart';

class DistributionVerifyScreen extends StatefulWidget {
  const DistributionVerifyScreen({super.key, required this.beneficiary});

  final Map<String, dynamic> beneficiary;

  @override
  State<DistributionVerifyScreen> createState() =>
      _DistributionVerifyScreenState();
}

class _DistributionVerifyScreenState extends State<DistributionVerifyScreen> {
  final service = DistributionService();
  final biometricService = BiometricService();

  bool verifying = false;
  bool rejecting = false;

  String _requiredBeneficiaryValue(String key) {
    final value = widget.beneficiary[key]?.toString();

    if (value == null || value.isEmpty) {
      throw Exception('Beneficiary is missing $key');
    }

    return value;
  }

  Future<bool> confirmFaceMatch(String faceUrl) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Face Match'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.network(
                  faceUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Does the live beneficiary match this registered photo?',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text('Yes, matches'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  String _beneficiaryValue(String key, {String fallback = 'N/A'}) {
    return fieldDisplayValue(widget.beneficiary[key], fallback: fallback);
  }

  Future<void> verifyAndDistribute() async {
    if (verifying) return;

    setState(() {
      verifying = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final beneficiaryId = _requiredBeneficiaryValue('id');
      final programId = _requiredBeneficiaryValue('program_id');
      final tenantId = _requiredBeneficiaryValue('tenant_id');
      final locationId = _requiredBeneficiaryValue('location_id');

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Checking previous distributions...')),
      );

      final alreadyReceived = await service.hasReceivedAidAlready(
        beneficiaryId: beneficiaryId,
        programId: programId,
      );

      if (!mounted) return;

      if (alreadyReceived) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Beneficiary has already received aid.'),
          ),
        );
        return;
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Loading registered face photo...')),
      );

      final faceUrl = await biometricService.getSignedFacePhotoUrl(
        beneficiaryId,
      );

      if (!mounted) return;

      if (faceUrl == null) {
        await service.recordDistributionRejected(
          tenantId: tenantId,
          programId: programId,
          beneficiaryId: beneficiaryId,
          locationId: locationId,
          reason: 'No registered face photo found',
          verificationMethod: 'face',
        );

        if (!mounted) return;

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No registered face photo found. Distribution blocked.',
            ),
          ),
        );
        return;
      }

      final faceConfirmed = await confirmFaceMatch(faceUrl);

      if (!mounted) return;

      if (!faceConfirmed) {
        await service.recordDistributionRejected(
          tenantId: tenantId,
          programId: programId,
          beneficiaryId: beneficiaryId,
          locationId: locationId,
          reason: 'Face verification rejected',
          verificationMethod: 'face',
        );

        if (!mounted) return;

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Face verification rejected.')),
        );
        return;
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Checking simulated fingerprint...')),
      );

      final fingerprintMatched = await biometricService
          .verifySimulatedFingerprint(beneficiaryId);

      if (!mounted) return;

      if (!fingerprintMatched) {
        await service.recordDistributionRejected(
          tenantId: tenantId,
          programId: programId,
          beneficiaryId: beneficiaryId,
          locationId: locationId,
          reason: 'Fingerprint verification failed',
          verificationMethod: 'fingerprint',
        );

        if (!mounted) return;

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Fingerprint verification failed. Distribution blocked.',
            ),
          ),
        );
        return;
      }

      await service.recordDistributionSuccess(
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
        itemName: 'Fertilizer',
        quantity: 1,
        verificationMethod: 'face_fingerprint',
      );

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Face and fingerprint matched. Distribution recorded.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Verification failed. Check logs.')),
      );

      debugPrint('Distribution verification error: $e');
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  Future<void> rejectDistribution() async {
    if (verifying || rejecting) return;

    setState(() {
      rejecting = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final beneficiaryId = _requiredBeneficiaryValue('id');
      final programId = _requiredBeneficiaryValue('program_id');
      final tenantId = _requiredBeneficiaryValue('tenant_id');
      final locationId = _requiredBeneficiaryValue('location_id');

      await service.recordDistributionRejected(
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
        reason: 'Manual field rejection',
        verificationMethod: 'manual',
      );

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Distribution rejected.')),
      );
    } catch (e) {
      debugPrint('Distribution rejection error: $e');

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Reject failed. Check logs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          rejecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final beneficiary = widget.beneficiary;
    final beneficiaryName = _beneficiaryValue(
      'full_name',
      fallback: 'Unnamed Beneficiary',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify & Distribute'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            FieldSurface(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldPhotoAvatar(label: beneficiaryName, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beneficiaryName,
                          softWrap: true,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: ${_beneficiaryValue('national_id')}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Phone: ${_beneficiaryValue('phone')}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        FieldStatusPill(
                          label: fieldDisplayValue(
                            beneficiary['status'],
                            fallback: 'Verified',
                          ),
                          icon: Icons.check,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FieldSurface(
              color: AppColors.amberSoft,
              borderColor: AppColors.amber.withValues(alpha: 0.32),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: AppColors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Duplicate Check Before Authorization',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Similar records are checked before aid is recorded.',
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Item to Distribute',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const _ReadOnlySelect(value: 'Fertilizer'),
            const SizedBox(height: 12),
            const Text(
              'Quantity',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const _QuantityDisplay(),
            const SizedBox(height: 14),
            FieldSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Verification Checks',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  FieldInfoRow(
                    icon: Icons.manage_search,
                    label: 'Duplicate Check',
                    value: 'Checked before authorization',
                  ),
                  SizedBox(height: 12),
                  FieldInfoRow(
                    icon: Icons.face_retouching_natural,
                    label: 'Face Match',
                    value: 'Confirmed from registered photo',
                  ),
                  SizedBox(height: 12),
                  FieldInfoRow(
                    icon: Icons.fingerprint,
                    label: 'Fingerprint',
                    value: 'Verified from active enrollment',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (verifying || rejecting)
                    ? null
                    : verifyAndDistribute,
                icon: verifying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  verifying ? 'Authorizing...' : 'Authorize Distribution',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: (verifying || rejecting) ? null : rejectDistribution,
                icon: rejecting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.close),
                label: Text(rejecting ? 'Rejecting...' : 'Reject Distribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlySelect extends StatelessWidget {
  const _ReadOnlySelect({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.expand_more, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _QuantityDisplay extends StatelessWidget {
  const _QuantityDisplay();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityButton(icon: Icons.remove),
        Expanded(
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: const Text(
              '1',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        _QuantityButton(icon: Icons.add),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(
          left: icon == Icons.remove ? const Radius.circular(8) : Radius.zero,
          right: icon == Icons.add ? const Radius.circular(8) : Radius.zero,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.text, size: 18),
    );
  }
}
