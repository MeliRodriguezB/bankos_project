class AuthUserModel {
  final String id;
  final String name;
  final String email;
  final String tenantId;
  final String? membershipId;
  final List<String> roles;

  AuthUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.tenantId,
    this.membershipId,
    required this.roles,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      membershipId: json['membership_id']?.toString(),
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['CUSTOMER'],
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUserModel user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 1800,
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}
