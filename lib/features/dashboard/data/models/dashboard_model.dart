import 'account_model.dart';
import 'balance_summary_model.dart';

class DashboardModel {
  final String userId;
  final String userName;
  final String userEmail;
  final String tenantId;
  final String tenantName;
  final List<BalanceSummaryModel> balancesByCurrency;
  final List<AccountModel> accounts;

  DashboardModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.tenantId,
    required this.tenantName,
    required this.balancesByCurrency,
    required this.accounts,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    final tenantJson = json['tenant'] as Map<String, dynamic>? ?? {};
    final balancesList = json['balances_by_currency'] as List<dynamic>? ?? [];
    final accountsList = json['accounts'] as List<dynamic>? ?? [];

    return DashboardModel(
      userId: userJson['id']?.toString() ?? '',
      userName: userJson['name']?.toString() ?? 'Usuario BankOS',
      userEmail: userJson['email']?.toString() ?? '',
      tenantId: tenantJson['id']?.toString() ?? '',
      tenantName: tenantJson['name']?.toString() ?? 'Institución Financiera',
      balancesByCurrency: balancesList
          .map((item) => BalanceSummaryModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      accounts: accountsList
          .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
