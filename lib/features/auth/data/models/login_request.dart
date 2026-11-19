class LoginRequest {
  final String tenantSlug;
  final String email;
  final String password;

  LoginRequest({
    required this.tenantSlug,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'tenant_slug': tenantSlug,
      'email': email,
      'password': password,
    };
  }
}
