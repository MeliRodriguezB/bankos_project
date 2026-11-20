import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// Provides access to the device's biometric authentication prompt.
///
/// Biometrics are verified locally by the operating system. BankOS never receives
/// biometric images, templates, or sensor data.
class BiometricService {
  BiometricService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  /// Checks whether biometric hardware and an enrolled biometric are available.
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final biometrics = await _authentication.getAvailableBiometrics();
      return supported && biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Describes the biometric option intended for this platform.
  String get platformLabel => Platform.isIOS ? 'Face ID' : 'Huella dactilar';

  /// Opens the native biometric prompt. It does not authenticate against BankOS;
  /// callers must only use it to unlock a locally stored session.
  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Confirma tu identidad para acceder a BankOS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
