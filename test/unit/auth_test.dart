import 'package:flutter_test/flutter_test.dart';
import 'package:bankos_project/features/auth/data/models/login_request.dart';
import 'package:bankos_project/features/auth/data/models/auth_response.dart';
import 'package:bankos_project/features/auth/data/repositories/auth_repository.dart';

void main() {
  group('Auth Tests (Persona 1)', () {
    test('LoginRequest genera JSON adecuado con tenant_slug', () {
      final req = LoginRequest(
        tenantSlug: 'cooperativa-futuro',
        email: 'carlos@fintech.com',
        password: 'secretpassword',
      );

      final json = req.toJson();
      expect(json['tenant_slug'], 'cooperativa-futuro');
      expect(json['email'], 'carlos@fintech.com');
      expect(json['password'], 'secretpassword');
    });

    test('AuthResponse deserializa payload JWT y usuario', () {
      final json = {
        'access_token': 'test_jwt_token',
        'token_type': 'bearer',
        'expires_in': 1800,
        'user': {
          'id': 'usr-101',
          'name': 'Carlos Mendoza',
          'email': 'carlos@fintech.com',
          'tenant_id': 'tenant-coop-01',
          'membership_id': 'mem-01',
          'roles': ['CUSTOMER'],
        }
      };

      final response = AuthResponse.fromJson(json);
      expect(response.accessToken, 'test_jwt_token');
      expect(response.user.name, 'Carlos Mendoza');
      expect(response.user.tenantId, 'tenant-coop-01');
      expect(response.user.roles, contains('CUSTOMER'));
    });

    test('MockAuthRepository autentica con credenciales válidas', () async {
      final repo = MockAuthRepository();
      final response = await repo.login(
        LoginRequest(
          tenantSlug: 'cooperativa-futuro',
          email: 'carlos@fintech.com',
          password: '123456',
        ),
      );

      expect(response.accessToken.isNotEmpty, isTrue);
      expect(response.user.name, 'Carlos Mendoza');
    });

    test('MockAuthRepository rechaza contraseña incorrecta', () async {
      final repo = MockAuthRepository();
      expect(
        () => repo.login(
          LoginRequest(
            tenantSlug: 'cooperativa-futuro',
            email: 'carlos@fintech.com',
            password: 'wrong_password',
          ),
        ),
        throwsA(anything),
      );
    });
  });
}
