import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../../services/biometric_service.dart';

class FingerprintEnrollmentScreen extends StatefulWidget {
  final String beneficiaryId;
  final String tenantId;

  const FingerprintEnrollmentScreen({
    super.key,
    required this.beneficiaryId,
    required this.tenantId,
  });

  @override
  State<FingerprintEnrollmentScreen> createState() =>
      _FingerprintEnrollmentScreenState();
}

class _FingerprintEnrollmentScreenState
    extends State<FingerprintEnrollmentScreen> {
  final BiometricService _biometricService = BiometricService();

  bool _scanning = false;
  bool _enrolled = false;

  Future<void> _scanFingerprint() async {
    try {
      setState(() {
        _scanning = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      await _biometricService.enrollSimulatedFingerprint(
        beneficiaryId: widget.beneficiaryId,
        tenantId: widget.tenantId,
      );

      if (!mounted) return;

      setState(() {
        _enrolled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fingerprint enrolled successfully')),
      );
    } catch (e) {
      debugPrint('Fingerprint enrollment failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fingerprint enrollment failed.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  void _submitRegistration() {
    if (!_enrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll fingerprint before submitting'),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint Enrollment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FieldSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 136,
                      width: 136,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _enrolled
                            ? AppColors.primarySoft
                            : AppColors.infoSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        size: 88,
                        color: _enrolled ? AppColors.primary : AppColors.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _enrolled
                        ? 'Fingerprint enrolled'
                        : _scanning
                        ? 'Scanning fingerprint...'
                        : 'Place beneficiary finger on scanner',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MVP mode: fingerprint is simulated and SecuGen-ready. This screen will later connect to the real SecuGen SDK.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _scanFingerprint,
                icon: _scanning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  _scanning
                      ? 'Scanning...'
                      : _enrolled
                      ? 'Scan Again'
                      : 'Scan Fingerprint',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitRegistration,
                icon: const Icon(Icons.check_circle),
                label: const Text('Submit Registration'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
