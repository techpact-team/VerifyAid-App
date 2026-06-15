import 'package:flutter/material.dart';

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fingerprint enrollment failed: $e')),
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.popUntil((route) => route.isFirst);

    messenger.showSnackBar(
      const SnackBar(content: Text('Beneficiary registration completed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint Enrollment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.fingerprint,
                size: 120,
                color: _enrolled ? Colors.green : Colors.blueGrey,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MVP mode: fingerprint is simulated and SecuGen-ready. '
                'This screen will later connect to the real SecuGen SDK.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _scanFingerprint,
                  icon: const Icon(Icons.fingerprint),
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
      ),
    );
  }
}
