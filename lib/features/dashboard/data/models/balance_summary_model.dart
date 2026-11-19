class BalanceSummaryModel {
  final String currency;
  final String totalBalance;
  final int activeAccountsCount;

  BalanceSummaryModel({
    required this.currency,
    required this.totalBalance,
    required this.activeAccountsCount,
  });

  factory BalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return BalanceSummaryModel(
      currency: json['currency'] as String? ?? 'COP',
      totalBalance: json['total_balance']?.toString() ?? '0.00',
      activeAccountsCount: (json['active_accounts_count'] as num?)?.toInt() ?? 0,
    );
  }
}
