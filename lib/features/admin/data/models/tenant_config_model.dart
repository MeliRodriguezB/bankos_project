class TenantConfigModel {
  final String maxTransferAmount;
  final Map<String, String> transferFees;
  final String transferFeePercent;
  final String primaryCurrency;
  final List<String> supportedCurrencies;
  final Map<String, String> exchangeRates;
  final String? webhookUrl;

  const TenantConfigModel({
    required this.maxTransferAmount,
    required this.transferFees,
    required this.transferFeePercent,
    required this.primaryCurrency,
    required this.supportedCurrencies,
    required this.exchangeRates,
    required this.webhookUrl,
  });

  factory TenantConfigModel.fromJson(Map<String, dynamic> json) {
    return TenantConfigModel(
      maxTransferAmount: json['max_transfer_amount']?.toString() ?? '0.00',
      transferFees: _stringMap(json['transfer_fees']),
      transferFeePercent: json['transfer_fee_percent']?.toString() ?? '0',
      primaryCurrency: json['primary_currency']?.toString() ?? 'COP',
      supportedCurrencies: (json['supported_currencies'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().toUpperCase())
          .toList(),
      exchangeRates: _stringMap(json['exchange_rates']),
      webhookUrl: json['webhook_url']?.toString(),
    );
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, item) => MapEntry(key.toString(), item.toString()),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'max_transfer_amount': maxTransferAmount,
        'transfer_fees': transferFees,
        'transfer_fee_percent': transferFeePercent,
        'primary_currency': primaryCurrency,
        'supported_currencies': supportedCurrencies,
        'exchange_rates': exchangeRates,
        'webhook_url': webhookUrl,
      };
}
