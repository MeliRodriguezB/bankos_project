import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// Provides local device biometric authentication for session unlocking.
class BiometricService {
  BiometricService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final biometrics = await _authentication.getAvailableBiometrics();
      return supported && biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String get platformLabel => Platform.isIOS ? 'Face ID' : 'Huella dactilar';

  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Confirma tu identidad para acceder a BankOS',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
