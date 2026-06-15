// ignore: depend_on_referenced_packages
import 'package:local_auth/local_auth.dart';

class AndroidBiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    final isSupported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return isSupported && canCheck;
  }

  Future<bool> authenticateForEnrollment() async {
    final canUse = await canUseBiometrics();

    if (!canUse) {
      throw Exception(
        'Biometric authentication is not available on this device',
      );
    }

    return _auth.authenticate(
      localizedReason: 'Authenticate to enroll beneficiary fingerprint',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<bool> authenticateForDistribution() async {
    final canUse = await canUseBiometrics();

    if (!canUse) {
      throw Exception(
        'Biometric authentication is not available on this device',
      );
    }

    return _auth.authenticate(
      localizedReason: 'Authenticate to verify beneficiary before distribution',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
