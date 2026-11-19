import '../../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(LoginRequest request);
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _apiClient;

  ApiAuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.post('/auth/login', request.toJson());
    return AuthResponse.fromJson(response as Map<String, dynamic>);
  }
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthResponse> login(LoginRequest request) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (request.email.isEmpty || request.password.isEmpty) {
      throw ApiException(
        statusCode: 400,
        message: 'Por favor ingresa tu correo y contraseña.',
      );
    }

    if (request.password != '123456') {
      throw ApiException(
        statusCode: 401,
        message: 'Contraseña incorrecta. (Prueba: 123456)',
      );
    }

    return AuthResponse(
      accessToken: 'mock_jwt_token_carlos_mendoza',
      tokenType: 'bearer',
      expiresIn: 1800,
      user: AuthUserModel(
        id: 'usr-dev-101',
        name: 'Carlos Mendoza',
        email: request.email,
        tenantId: request.tenantSlug,
        membershipId: 'mem-901',
        roles: ['CUSTOMER'],
      ),
    );
  }
}
