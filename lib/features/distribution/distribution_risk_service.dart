import 'dart:math';

/// Risk levels for distribution authorization decisions.
enum RiskLevel { low, medium, high, blocked }

/// Result of a risk assessment for a distribution attempt.
class RiskAssessment {
  const RiskAssessment({
    required this.level,
    required this.reasons,
    required this.faceScanRequired,
    required this.faceScanRecommended,
  });

  final RiskLevel level;
  final List<String> reasons;
  final bool faceScanRequired;
  final bool faceScanRecommended;

  String get label {
    return switch (level) {
      RiskLevel.low => 'Low Risk',
      RiskLevel.medium => 'Medium Risk',
      RiskLevel.high => 'High Risk',
      RiskLevel.blocked => 'Blocked',
    };
  }

  String get summary {
    if (reasons.isEmpty) return 'No risk factors detected.';
    return reasons.join('. ');
  }

  Map<String, dynamic> toAuditMetadata() {
    return {
      'risk_level': level.name,
      'risk_reasons': reasons,
      'face_scan_required': faceScanRequired,
      'face_scan_recommended': faceScanRecommended,
    };
  }
}

/// Evaluates distribution risk based on known factors.
///
/// This service is pure logic — no Supabase or I/O dependencies.
/// All data is passed in; the service returns a risk assessment.
class DistributionRiskService {
  const DistributionRiskService();

  /// Default random audit percentage (5% = 1 in 20).
  static const double randomAuditPercentage = 0.05;

  /// Evaluate risk for a distribution attempt.
  RiskAssessment assess({
    required bool alreadyReceived,
    required bool hasRegisteredPhoto,
    required String beneficiaryStatus,
    bool officerMarkedUncertain = false,
    bool qrDataMismatch = false,
    bool isRandomAudit = false,
  }) {
    final reasons = <String>[];
    var level = RiskLevel.low;
    var faceScanRequired = false;
    var faceScanRecommended = false;

    // ── Blocked conditions ──────────────────────────────────────────────

    if (alreadyReceived) {
      return const RiskAssessment(
        level: RiskLevel.blocked,
        reasons: ['Beneficiary has already received aid for this program'],
        faceScanRequired: false,
        faceScanRecommended: false,
      );
    }

    final normalizedStatus = beneficiaryStatus.trim().toLowerCase();
    if (normalizedStatus == 'inactive' || normalizedStatus == 'suspended') {
      return RiskAssessment(
        level: RiskLevel.blocked,
        reasons: ['Beneficiary status is $normalizedStatus'],
        faceScanRequired: false,
        faceScanRecommended: false,
      );
    }

    // ── High risk conditions ────────────────────────────────────────────

    if (officerMarkedUncertain) {
      reasons.add('Officer marked identity as uncertain');
      level = RiskLevel.high;
      faceScanRequired = true;
    }

    if (qrDataMismatch) {
      reasons.add('QR code data does not match beneficiary record');
      level = RiskLevel.high;
      faceScanRequired = true;
    }

    // ── Medium risk conditions ──────────────────────────────────────────

    if (!hasRegisteredPhoto) {
      reasons.add('No registered photo on file');
      if (level.index < RiskLevel.medium.index) {
        level = RiskLevel.medium;
      }
      faceScanRecommended = true;
    }

    if (isRandomAudit) {
      reasons.add('Selected for random audit');
      if (level.index < RiskLevel.medium.index) {
        level = RiskLevel.medium;
      }
      faceScanRecommended = true;
    }

    // ── Low risk (default) ──────────────────────────────────────────────

    if (reasons.isEmpty) {
      reasons.add('No risk factors detected');
    }

    return RiskAssessment(
      level: level,
      reasons: reasons,
      faceScanRequired: faceScanRequired,
      faceScanRecommended: faceScanRecommended || faceScanRequired,
    );
  }

  /// Determine if this distribution should be a random audit.
  bool shouldRandomAudit() {
    return Random().nextDouble() < randomAuditPercentage;
  }
}
