import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacena el token de sesión usando almacenamiento seguro de la plataforma.
class SessionStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'bankos_access_token';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);\n\n  static const String _biometricKey = 'bankos_biometric_enabled';\n\n  Future<bool> isBiometricEnabled() async =>\n      (await _storage.read(key: _biometricKey)) == 'true';\n\n  Future<void> setBiometricEnabled(bool enabled) =>\n      _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
}
