class TransactionModel {
  final String id;
  final String type; // TRANSFER, DEPOSIT, WITHDRAWAL
  final String amount;
  final String currency;
  final String feeAmount;
  final String exchangeRate;
  final String? convertedAmount;
  final String? destinationCurrency;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String status;
  final String? idempotencyKey;
  final String? correlationId;
  final String? description;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.feeAmount,
    required this.exchangeRate,
    this.convertedAmount,
    this.destinationCurrency,
    this.sourceAccountId,
    this.destinationAccountId,
    required this.status,
    this.idempotencyKey,
    this.correlationId,
    this.description,
    required this.createdAt,
  });

  bool get hasFee => (double.tryParse(feeAmount) ?? 0.0) > 0.0;
  bool get hasConversion => (destinationCurrency != null && destinationCurrency != currency);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'TRANSFER',
      amount: json['amount']?.toString() ?? '0.00',
      currency: json['currency']?.toString() ?? 'COP',
      feeAmount: json['fee_amount']?.toString() ?? '0.00',
      exchangeRate: json['exchange_rate']?.toString() ?? '1.000000',
      convertedAmount: json['converted_amount']?.toString(),
      destinationCurrency: json['destination_currency']?.toString(),
      sourceAccountId: json['source_account_id']?.toString(),
      destinationAccountId: json['destination_account_id']?.toString(),
      status: json['status']?.toString() ?? 'COMPLETED',
      idempotencyKey: json['idempotency_key']?.toString(),
      correlationId: json['correlation_id']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
