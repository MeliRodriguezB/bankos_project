class AccountModel {
  final String id;
  final String accountNumber;
  final String accountNumberMasked;
  final String? alias;
  final String balance; // Representado como String para evitar pérdidas de precisión flotante
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AccountModel({
    required this.id,
    required this.accountNumber,
    required this.accountNumberMasked,
    this.alias,
    required this.balance,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isInactive => status.toUpperCase() == 'INACTIVE';
  bool get isBlocked => status.toUpperCase() == 'BLOCKED';

  String get displayName => (alias != null && alias!.trim().isNotEmpty)
      ? alias!
      : 'Cuenta $currency';

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountNumberMasked: json['account_number_masked'] as String? ?? '••••',
      alias: json['alias'] as String?,
      balance: json['balance']?.toString() ?? '0.00',
      currency: json['currency'] as String? ?? 'COP',
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_number': accountNumber,
      'account_number_masked': accountNumberMasked,
      'alias': alias,
      'balance': balance,
      'currency': currency,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
