import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../face_verification/face_verification_result.dart';
import '../face_verification/face_verification_service.dart';
import 'distribution_risk_service.dart';
import 'distribution_service.dart';

class DistributionVerifyScreen extends StatefulWidget {
  const DistributionVerifyScreen({
    super.key,
    required this.beneficiary,
    this.lookupMethod = 'search',
  });

  final Map<String, dynamic> beneficiary;
  final String lookupMethod;

  @override
  State<DistributionVerifyScreen> createState() =>
      _DistributionVerifyScreenState();
}

class _DistributionVerifyScreenState extends State<DistributionVerifyScreen> {
  final service = DistributionService();
  final faceVerificationService = FaceVerificationService();
  final riskService = const DistributionRiskService();

  // ── Processing states ──────────────────────────────────────────────────
  bool verifying = false;
  bool rejecting = false;
  bool scanningFace = false;

  // ── Data loading states ────────────────────────────────────────────────
  bool loadingRegisteredFace = true;
  bool loadingDuplicateCheck = true;
  bool loadingRegisteredPhoto = true;

  // ── Core data ──────────────────────────────────────────────────────────
  bool alreadyReceived = false;
  String? registeredFacePath;
  String? registeredFaceUrl;
  String? registeredPhotoUrl;
  FaceVerificationResult? faceVerificationResult;

  // ── Officer decisions ──────────────────────────────────────────────────
  bool officerConfirmedIdentity = false;
  bool officerMarkedUncertain = false;
  bool manualFallbackConfirmed = false;

  // ── Risk assessment ────────────────────────────────────────────────────
  RiskAssessment? riskAssessment;
  late final bool isRandomAudit;

  // ── Distribution details ───────────────────────────────────────────────
  final itemNameController = TextEditingController(text: 'Fertilizer');
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    isRandomAudit = riskService.shouldRandomAudit();
    checkDuplicateDistribution();
    loadRegisteredFace();
    loadRegisteredPhoto();
  }

  @override
  void dispose() {
    itemNameController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────

  Future<void> checkDuplicateDistribution() async {
    try {
      final beneficiaryId = _requiredBeneficiaryValue('id');
      final programId = _requiredBeneficiaryValue('program_id');

      final hasReceived = await service.hasReceivedAidAlready(
        beneficiaryId: beneficiaryId,
        programId: programId,
      );

      if (!mounted) return;
      setState(() {
        alreadyReceived = hasReceived;
        loadingDuplicateCheck = false;
      });
      _recalculateRisk();
    } catch (e) {
      debugPrint('Error checking duplicate distribution: $e');
      if (!mounted) return;
      setState(() {
        loadingDuplicateCheck = false;
      });
      _recalculateRisk();
    }
  }

  Future<void> loadRegisteredFace() async {
    try {
      final beneficiaryId = _requiredBeneficiaryValue('id');
      final path = await faceVerificationService.getRegisteredFacePath(
        beneficiaryId: beneficiaryId,
        beneficiary: widget.beneficiary,
      );
      final url = await faceVerificationService.getSignedFaceUrl(path);

      if (!mounted) return;
      setState(() {
        registeredFacePath = path;
        registeredFaceUrl = url;
        loadingRegisteredFace = false;
      });
    } catch (error) {
      debugPrint('Registered face preview failed: $error');
      if (!mounted) return;
      setState(() {
        loadingRegisteredFace = false;
      });
    }
  }

  Future<void> loadRegisteredPhoto() async {
    try {
      final photoUrl = widget.beneficiary['photo_url']?.toString();
      final signedUrl = await service.getSignedPhotoUrl(photoUrl);

      if (!mounted) return;
      setState(() {
        registeredPhotoUrl = signedUrl;
        loadingRegisteredPhoto = false;
      });
      _recalculateRisk();
    } catch (error) {
      debugPrint('Registered photo load failed: $error');
      if (!mounted) return;
      setState(() {
        loadingRegisteredPhoto = false;
      });
      _recalculateRisk();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _requiredBeneficiaryValue(String key) {
    final value = widget.beneficiary[key]?.toString();

    if (value == null || value.isEmpty) {
      throw Exception('Beneficiary is missing $key');
    }

    return value;
  }

  String _beneficiaryValue(String key, {String fallback = 'N/A'}) {
    return fieldDisplayValue(widget.beneficiary[key], fallback: fallback);
  }

  bool get _hasRegisteredPhoto {
    return registeredPhotoUrl != null || registeredFaceUrl != null;
  }

  String get _beneficiaryStatus {
    return widget.beneficiary['status']?.toString().trim().toLowerCase() ??
        'active';
  }

  // ── Risk assessment ────────────────────────────────────────────────────

  void _recalculateRisk() {
    if (loadingDuplicateCheck) return;

    final assessment = riskService.assess(
      alreadyReceived: alreadyReceived,
      hasRegisteredPhoto: _hasRegisteredPhoto || loadingRegisteredPhoto,
      beneficiaryStatus: _beneficiaryStatus,
      officerMarkedUncertain: officerMarkedUncertain,
      isRandomAudit: isRandomAudit,
    );

    if (!mounted) return;
    setState(() {
      riskAssessment = assessment;
    });
  }

  // ── Authorization logic ────────────────────────────────────────────────

  bool get _manualFallbackAvailable {
    return faceVerificationResult?.status ==
        FaceVerificationStatus.engineUnavailable;
  }

  bool get _faceScanPassed {
    return faceVerificationResult?.isMatched == true;
  }

  bool get _canAuthorizeDistribution {
    if (alreadyReceived || loadingDuplicateCheck) return false;

    final status = _beneficiaryStatus;
    if (status == 'inactive' || status == 'suspended') return false;

    final risk = riskAssessment;
    if (risk == null) return false;
    if (risk.level == RiskLevel.blocked) return false;

    // Face scan passed → always allow
    if (_faceScanPassed) return true;

    // Manual fallback confirmed when engine unavailable → allow
    if (_manualFallbackAvailable && manualFallbackConfirmed) return true;

    // High risk → require face scan or manual fallback
    if (risk.level == RiskLevel.high) {
      return false;
    }

    // Officer marked uncertain → require face scan resolution
    if (officerMarkedUncertain) return false;

    // Low / medium risk → officer photo confirmation is enough
    if (officerConfirmedIdentity) return true;

    return false;
  }

  String _authorizationBlockedMessage() {
    if (alreadyReceived) return 'Duplicate distribution is blocked.';
    if (loadingDuplicateCheck) return 'Wait for duplicate check.';

    final status = _beneficiaryStatus;
    if (status == 'inactive' || status == 'suspended') {
      return 'Beneficiary status is $status.';
    }

    final risk = riskAssessment;
    if (risk == null) return 'Evaluating risk…';
    if (risk.level == RiskLevel.blocked) return risk.summary;

    if (risk.level == RiskLevel.high && !_faceScanPassed) {
      if (_manualFallbackAvailable && !manualFallbackConfirmed) {
        return 'Confirm manual fallback before authorizing.';
      }
      return 'High risk — face scan or manual fallback required.';
    }

    if (officerMarkedUncertain && !_faceScanPassed) {
      if (_manualFallbackAvailable && !manualFallbackConfirmed) {
        return 'Confirm manual fallback before authorizing.';
      }
      return 'Identity uncertain — face scan required.';
    }

    if (!officerConfirmedIdentity) {
      return 'Confirm the beneficiary\'s identity to proceed.';
    }

    return 'Cannot authorize at this time.';
  }

  // ── Verification method for audit ──────────────────────────────────────

  String get _verificationMethod {
    if (_faceScanPassed) return 'face_recognition';
    if (_manualFallbackAvailable && manualFallbackConfirmed) {
      return 'manual_photo_confirmation';
    }
    return 'manual_photo_confirmation';
  }

  String get _verificationStatus {
    if (_faceScanPassed) return 'matched';
    if (_manualFallbackAvailable && manualFallbackConfirmed) {
      return 'manual_confirmed';
    }
    if (officerConfirmedIdentity) return 'confirmed';
    return 'pending';
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> scanLiveFace() async {
    if (scanningFace) return;

    setState(() {
      scanningFace = true;
      manualFallbackConfirmed = false;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final result = await faceVerificationService.scanAndVerify(
        beneficiary: widget.beneficiary,
        tenantId: _requiredBeneficiaryValue('tenant_id'),
        programId: _requiredBeneficiaryValue('program_id'),
        beneficiaryId: _requiredBeneficiaryValue('id'),
        locationId: _requiredBeneficiaryValue('location_id'),
      );

      if (result == null) return;
      if (!mounted) return;

      setState(() {
        faceVerificationResult = result;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result.statusLabel)),
      );
    } catch (error) {
      debugPrint('Live face scan failed: $error');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Face scan failed. Check logs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          scanningFace = false;
        });
      }
    }
  }

  Future<void> verifyAndDistribute() async {
    if (verifying) return;

    if (!_canAuthorizeDistribution) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authorizationBlockedMessage())));
      return;
    }

    setState(() {
      verifying = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final beneficiaryId = _requiredBeneficiaryValue('id');
      final programId = _requiredBeneficiaryValue('program_id');
      final tenantId = _requiredBeneficiaryValue('tenant_id');
      final locationId = _requiredBeneficiaryValue('location_id');
      final itemName = itemNameController.text.trim().isEmpty
          ? 'Fertilizer'
          : itemNameController.text.trim();

      final eventId = await service.recordDistributionSuccess(
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
        itemName: itemName,
        quantity: quantity,
        verificationMethod: _verificationMethod,
        verificationStatus: _verificationStatus,
        metadata: _buildSuccessMetadata(),
      );

      if (!mounted) return;

      // Record face verification attempt if a scan was done
      if (faceVerificationResult != null) {
        await faceVerificationService.recordAttempt(
          result: faceVerificationResult!,
          tenantId: tenantId,
          programId: programId,
          beneficiaryId: beneficiaryId,
          locationId: locationId,
          distributionEventId: eventId,
        );
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Distribution recorded.')),
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

    final reason = await _askRejectReason();
    if (reason == null || reason.trim().isEmpty) return;
    if (!mounted) return;

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
        reason: alreadyReceived ? 'Duplicate distribution warning' : reason,
        verificationMethod: _rejectionVerificationMethod(),
        verificationStatus:
            faceVerificationResult?.status.name ?? 'not_scanned',
        metadata: _buildRejectionMetadata(reason),
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

  // ── Metadata builders ──────────────────────────────────────────────────

  Map<String, dynamic> _buildSuccessMetadata() {
    final risk = riskAssessment;
    final faceScanPerformed = faceVerificationResult != null;

    final metadata = <String, dynamic>{
      'source': 'flutter_mobile',
      'flow': _faceScanPassed
          ? 'risk_based_face_verification'
          : 'fast_distribution',
      'lookup_method': widget.lookupMethod,
      'duplicate_check_passed': !alreadyReceived,
      'risk_level': risk?.level.name ?? 'unknown',
      'risk_reasons': risk?.reasons ?? [],
      'face_scan_required': risk?.faceScanRequired ?? false,
      'face_scan_performed': faceScanPerformed,
      'officer_confirmed_identity': officerConfirmedIdentity,
      'officer_marked_uncertain': officerMarkedUncertain,
      'random_audit': isRandomAudit,
    };

    if (faceVerificationResult != null) {
      final result = faceVerificationResult!;
      metadata.addAll({
        'match_score': result.matchScore,
        'threshold': result.threshold,
        'quality_score': result.qualityScore,
        'liveness_passed': result.livenessPassed,
        'algorithm': result.metadata['algorithm'],
        'model_version': result.metadata['model_version'],
        'face_verification_status': result.status.name,
      });
    }

    if (_manualFallbackAvailable && manualFallbackConfirmed) {
      metadata['reason'] = 'face_recognition_engine_unavailable';
    }

    return metadata;
  }

  Map<String, dynamic> _buildRejectionMetadata(String reason) {
    final risk = riskAssessment;
    return {
      'source': 'flutter_mobile',
      'flow': 'distribution_rejection',
      'lookup_method': widget.lookupMethod,
      'reason': reason,
      'risk_level': risk?.level.name ?? 'unknown',
      'duplicate_check_passed': !alreadyReceived,
      'officer_confirmed_identity': officerConfirmedIdentity,
      'officer_marked_uncertain': officerMarkedUncertain,
      'face_scan_performed': faceVerificationResult != null,
      'face_verification_result': faceVerificationResult?.toAuditMetadata(),
    };
  }

  String _rejectionVerificationMethod() {
    final result = faceVerificationResult;
    if (result == null) return 'not_scanned';
    if (result.isMatched) return 'face_recognition';
    if (result.status == FaceVerificationStatus.engineUnavailable) {
      return 'manual_photo_confirmation';
    }
    return 'face_verification';
  }

  Future<String?> _askRejectReason() {
    final controller = TextEditingController(
      text: alreadyReceived ? 'Duplicate distribution warning' : '',
    );

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Distribution'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter rejection reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  // ── UI builders ────────────────────────────────────────────────────────

  Widget _buildRegisteredPhotoSection() {
    return FieldSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(
            icon: Icons.photo_camera_outlined,
            label: 'Registered Photo',
          ),
          const SizedBox(height: 14),
          if (loadingRegisteredPhoto)
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.faint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (registeredPhotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                registeredPhotoUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.muted, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Photo failed to load',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (registeredFaceUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                registeredFaceUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.muted, size: 32),
                  );
                },
              ),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.amber.withValues(alpha: 0.24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.no_photography_outlined,
                      color: AppColors.amber, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No registered photo on file',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Visual identity confirmation may not be possible',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDuplicateCheckBanner() {
    if (loadingDuplicateCheck) {
      return FieldSurface(
        color: AppColors.canvas,
        borderColor: AppColors.border,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.muted,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking database for prior distributions…',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (alreadyReceived) {
      return FieldSurface(
        color: AppColors.dangerSoft,
        borderColor: AppColors.danger.withValues(alpha: 0.32),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FRAUD WARNING: Aid Already Received',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'This beneficiary has already received aid for this program. Double distribution is blocked by the system.',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return FieldSurface(
      color: const Color(0xFFE6F4EA),
      borderColor: const Color(0xFF137333).withValues(alpha: 0.24),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duplicate Check: Clear',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'No prior distribution recorded for this beneficiary under this program.',
            style: TextStyle(color: AppColors.text, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAssessmentBanner() {
    final risk = riskAssessment;
    if (risk == null) {
      return const SizedBox.shrink();
    }

    final color = switch (risk.level) {
      RiskLevel.low => AppColors.primary,
      RiskLevel.medium => AppColors.amber,
      RiskLevel.high => AppColors.danger,
      RiskLevel.blocked => AppColors.danger,
    };

    final icon = switch (risk.level) {
      RiskLevel.low => Icons.shield_outlined,
      RiskLevel.medium => Icons.warning_amber_rounded,
      RiskLevel.high => Icons.gpp_bad_outlined,
      RiskLevel.blocked => Icons.block_outlined,
    };

    final bgColor = switch (risk.level) {
      RiskLevel.low => AppColors.primarySoft,
      RiskLevel.medium => AppColors.amberSoft,
      RiskLevel.high => AppColors.dangerSoft,
      RiskLevel.blocked => AppColors.dangerSoft,
    };

    return FieldSurface(
      color: bgColor,
      borderColor: color.withValues(alpha: 0.24),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Risk Level: ${risk.label}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            risk.summary,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (risk.faceScanRequired) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.camera_front, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Live face scan required',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ] else if (risk.faceScanRecommended) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.camera_front, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Live face scan recommended',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentityConfirmationSection() {
    return FieldSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(
            icon: Icons.how_to_reg_outlined,
            label: 'Identity Confirmation',
          ),
          const SizedBox(height: 14),

          // ── Manual photo confirmation checkbox ─────────────────────────
          CheckboxListTile(
            value: officerConfirmedIdentity,
            onChanged: officerMarkedUncertain
                ? null
                : (value) {
                    setState(() {
                      officerConfirmedIdentity = value ?? false;
                    });
                  },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I confirm this person matches the registered photo',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'Visual identity verification by officer',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),

          const SizedBox(height: 10),

          // ── Identity uncertain button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    officerMarkedUncertain ? AppColors.danger : AppColors.amber,
                side: BorderSide(
                  color: officerMarkedUncertain
                      ? AppColors.danger
                      : AppColors.amber,
                ),
              ),
              onPressed: () {
                setState(() {
                  officerMarkedUncertain = !officerMarkedUncertain;
                  if (officerMarkedUncertain) {
                    officerConfirmedIdentity = false;
                  }
                });
                _recalculateRisk();
              },
              icon: Icon(
                officerMarkedUncertain
                    ? Icons.cancel_outlined
                    : Icons.help_outline,
                size: 18,
              ),
              label: Text(
                officerMarkedUncertain
                    ? 'Clear Uncertain Flag'
                    : 'Identity Uncertain',
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Optional live face scan button ─────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
              ),
              onPressed: scanningFace ? null : scanLiveFace,
              icon: scanningFace
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(scanningFace ? 'Scanning Face…' : 'Run Live Face Scan'),
            ),
          ),

          // ── Face scan result ───────────────────────────────────────────
          if (faceVerificationResult != null) ...[
            const SizedBox(height: 14),
            _buildFaceScanResult(),
          ],

          // ── Manual fallback when engine unavailable ────────────────────
          if (_manualFallbackAvailable) ...[
            const SizedBox(height: 10),
            CheckboxListTile(
              value: manualFallbackConfirmed,
              onChanged: (value) {
                setState(() {
                  manualFallbackConfirmed = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Use manual fallback',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              subtitle: const Text(
                'Recognition engine is not configured. This is not a biometric match.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaceScanResult() {
    final result = faceVerificationResult!;
    final color = _statusColor(result.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(result.status), color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.message,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ResultPill(
                      label: 'Quality',
                      value: result.qualityScore == null
                          ? 'N/A'
                          : result.qualityScore!.toStringAsFixed(0),
                    ),
                    _ResultPill(
                      label: 'Match',
                      value: result.matchScore == null
                          ? 'N/A'
                          : result.matchScore!.toStringAsFixed(2),
                    ),
                    _ResultPill(
                      label: 'Liveness',
                      value: result.livenessPassed == null
                          ? 'Not configured'
                          : (result.livenessPassed! ? 'Passed' : 'Failed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionDetails() {
    return FieldSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            icon: Icons.inventory_2_outlined,
            label: 'Distribution Details',
          ),
          const SizedBox(height: 12),
          const Text(
            'Item',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: itemNameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Fertilizer',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quantity',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                onPressed: quantity > 1
                    ? () => setState(() => quantity--)
                    : null,
              ),
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
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                onPressed: () => setState(() => quantity++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorizationGate() {
    final risk = riskAssessment;

    return FieldSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            icon: Icons.security_outlined,
            label: 'Authorization Gate',
          ),
          const SizedBox(height: 14),
          FieldInfoRow(
            icon: Icons.manage_search,
            label: 'Duplicate Check',
            value: loadingDuplicateCheck
                ? 'Checking…'
                : (alreadyReceived
                      ? 'DUPLICATE FOUND (Blocked)'
                      : 'Clear — No prior aid'),
            iconColor: loadingDuplicateCheck
                ? AppColors.muted
                : (alreadyReceived ? AppColors.danger : AppColors.primary),
          ),
          const SizedBox(height: 12),
          FieldInfoRow(
            icon: Icons.shield_outlined,
            label: 'Risk Level',
            value: risk?.label ?? 'Evaluating…',
            iconColor: risk == null
                ? AppColors.muted
                : switch (risk.level) {
                    RiskLevel.low => AppColors.primary,
                    RiskLevel.medium => AppColors.amber,
                    RiskLevel.high => AppColors.danger,
                    RiskLevel.blocked => AppColors.danger,
                  },
          ),
          const SizedBox(height: 12),
          FieldInfoRow(
            icon: Icons.how_to_reg_outlined,
            label: 'Verification Method',
            value: _verificationMethod == 'face_recognition'
                ? 'Face Recognition'
                : 'Manual Photo Confirmation',
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 12),
          FieldInfoRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Authorization',
            value: _canAuthorizeDistribution
                ? 'Ready to authorize'
                : _authorizationBlockedMessage(),
            iconColor: _canAuthorizeDistribution
                ? AppColors.primary
                : AppColors.amber,
          ),
        ],
      ),
    );
  }

  Color _statusColor(FaceVerificationStatus? status) {
    return switch (status) {
      FaceVerificationStatus.matched => AppColors.primary,
      FaceVerificationStatus.engineUnavailable ||
      FaceVerificationStatus.uncertain => AppColors.amber,
      FaceVerificationStatus.failed ||
      FaceVerificationStatus.noFaceDetected ||
      FaceVerificationStatus.multipleFacesDetected ||
      FaceVerificationStatus.poorQuality ||
      FaceVerificationStatus.livenessFailed ||
      FaceVerificationStatus.noRegisteredFace ||
      FaceVerificationStatus.error => AppColors.danger,
      null => AppColors.muted,
    };
  }

  IconData _statusIcon(FaceVerificationStatus status) {
    return switch (status) {
      FaceVerificationStatus.matched => Icons.verified_outlined,
      FaceVerificationStatus.engineUnavailable => Icons.info_outline,
      FaceVerificationStatus.uncertain => Icons.help_outline,
      FaceVerificationStatus.noRegisteredFace => Icons.no_accounts_outlined,
      FaceVerificationStatus.noFaceDetected => Icons.face_retouching_off,
      FaceVerificationStatus.multipleFacesDetected => Icons.groups_outlined,
      FaceVerificationStatus.poorQuality => Icons.blur_on_outlined,
      FaceVerificationStatus.livenessFailed => Icons.motion_photos_off,
      FaceVerificationStatus.failed => Icons.cancel_outlined,
      FaceVerificationStatus.error => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final beneficiary = widget.beneficiary;
    final beneficiaryName = _beneficiaryValue(
      'full_name',
      fallback: 'Unnamed Beneficiary',
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: const FieldBackButton(fallbackLocation: '/distribution'),
        title: const Text('Verify & Distribute'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            // ── Beneficiary card ──────────────────────────────────────────
            FieldSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldPhotoAvatar(label: beneficiaryName, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beneficiaryName,
                          softWrap: true,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MiniInfo(
                          icon: Icons.badge_outlined,
                          text: 'ID: ${_beneficiaryValue('national_id')}',
                        ),
                        const SizedBox(height: 4),
                        _MiniInfo(
                          icon: Icons.phone_outlined,
                          text: 'Phone: ${_beneficiaryValue('phone')}',
                        ),
                        if (widget.beneficiary['location_id'] != null) ...[
                          const SizedBox(height: 4),
                          _MiniInfo(
                            icon: Icons.location_on_outlined,
                            text:
                                'Location: ${_beneficiaryValue('location_id')}',
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FieldStatusPill(
                              label: fieldDisplayValue(
                                beneficiary['status'],
                                fallback: 'Registered',
                              ),
                              icon: Icons.verified_outlined,
                            ),
                            const SizedBox(width: 8),
                            FieldStatusPill(
                              label: widget.lookupMethod == 'qr'
                                  ? 'QR Scan'
                                  : 'Search',
                              icon: widget.lookupMethod == 'qr'
                                  ? Icons.qr_code
                                  : Icons.search,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Registered photo ──────────────────────────────────────────
            _buildRegisteredPhotoSection(),

            const SizedBox(height: 12),

            // ── Duplicate / fraud check ───────────────────────────────────
            _buildDuplicateCheckBanner(),

            const SizedBox(height: 12),

            // ── Risk assessment ───────────────────────────────────────────
            _buildRiskAssessmentBanner(),

            const SizedBox(height: 12),

            // ── Identity confirmation ─────────────────────────────────────
            _buildIdentityConfirmationSection(),

            const SizedBox(height: 12),

            // ── Distribution details ──────────────────────────────────────
            _buildDistributionDetails(),

            const SizedBox(height: 12),

            // ── Authorization gate summary ────────────────────────────────
            _buildAuthorizationGate(),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (verifying || rejecting || !_canAuthorizeDistribution)
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
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  verifying ? 'Authorizing…' : 'Authorize Distribution',
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
                    : const Icon(Icons.block_outlined),
                label: Text(rejecting ? 'Rejecting…' : 'Reject Distribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 16),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.white : AppColors.faint,
          borderRadius: BorderRadius.horizontal(
            left: icon == Icons.remove ? const Radius.circular(8) : Radius.zero,
            right: icon == Icons.add ? const Radius.circular(8) : Radius.zero,
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          color: onPressed != null ? AppColors.text : AppColors.muted,
          size: 18,
        ),
      ),
    );
  }
}
