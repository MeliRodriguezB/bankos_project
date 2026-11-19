class TransferQuoteModel {
  final String sourceCurrency;
  final String destinationCurrency;
  final String amountToDebit;
  final String feeAmount;
  final String totalDebited;
  final String exchangeRate;
  final String amountToCredit;
  final bool hasCurrencyConversion;
  final String destinationAccountMasked;

  TransferQuoteModel({
    required this.sourceCurrency,
    required this.destinationCurrency,
    required this.amountToDebit,
    required this.feeAmount,
    required this.totalDebited,
    required this.exchangeRate,
    required this.amountToCredit,
    required this.hasCurrencyConversion,
    required this.destinationAccountMasked,
  });

  factory TransferQuoteModel.fromJson(Map<String, dynamic> json) {
    return TransferQuoteModel(
      sourceCurrency: json['source_currency']?.toString() ?? 'COP',
      destinationCurrency: json['destination_currency']?.toString() ?? 'COP',
      amountToDebit: json['amount_to_debit']?.toString() ?? '0.00',
      feeAmount: json['fee_amount']?.toString() ?? '0.00',
      totalDebited: json['total_debited']?.toString() ?? '0.00',
      exchangeRate: json['exchange_rate']?.toString() ?? '1.000000',
      amountToCredit: json['amount_to_credit']?.toString() ?? '0.00',
      hasCurrencyConversion: json['has_currency_conversion'] as bool? ?? false,
      destinationAccountMasked: json['destination_account_masked']?.toString() ?? '••••',
    );
  }
}
