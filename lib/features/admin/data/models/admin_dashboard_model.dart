class AdminCurrencyBalance {
 final String currency; final String totalBalance; final int activeAccountsCount;
 AdminCurrencyBalance({required this.currency,required this.totalBalance,required this.activeAccountsCount});
 factory AdminCurrencyBalance.fromJson(Map<String,dynamic> j)=>AdminCurrencyBalance(currency:j['currency']?.toString()??'',totalBalance:j['total_balance']?.toString()??'0',activeAccountsCount:(j['active_accounts_count'] as num?)?.toInt()??0);
}
class AdminTransactionSummary {
 final String status,type,currency,totalAmount; final int count;
 AdminTransactionSummary({required this.status,required this.type,required this.currency,required this.totalAmount,required this.count});
 factory AdminTransactionSummary.fromJson(Map<String,dynamic> j)=>AdminTransactionSummary(status:j['status']?.toString()??'',type:j['type']?.toString()??'',currency:j['currency']?.toString()??'',totalAmount:j['total_amount']?.toString()??'0',count:(j['count'] as num?)?.toInt()??0);
}
class AdminDashboardModel {
 final String tenantId,tenantName; final int activeMemberships,totalAccounts,activeAccounts,inactiveAccounts,transactionsTotal; final List<AdminCurrencyBalance> balances; final List<AdminTransactionSummary> transactions;
 AdminDashboardModel({required this.tenantId,required this.tenantName,required this.activeMemberships,required this.totalAccounts,required this.activeAccounts,required this.inactiveAccounts,required this.transactionsTotal,required this.balances,required this.transactions});
 factory AdminDashboardModel.fromJson(Map<String,dynamic> j)=>AdminDashboardModel(tenantId:j['tenant_id']?.toString()??'',tenantName:j['tenant_name']?.toString()??'Institución',activeMemberships:(j['active_memberships'] as num?)?.toInt()??0,totalAccounts:(j['total_accounts'] as num?)?.toInt()??0,activeAccounts:(j['active_accounts'] as num?)?.toInt()??0,inactiveAccounts:(j['inactive_accounts'] as num?)?.toInt()??0,transactionsTotal:(j['transactions_total'] as num?)?.toInt()??0,balances:(j['balances_by_currency'] as List<dynamic>? ?? []).map((x)=>AdminCurrencyBalance.fromJson(x as Map<String,dynamic>)).toList(),transactions:(j['transactions_by_status_currency'] as List<dynamic>? ?? []).map((x)=>AdminTransactionSummary.fromJson(x as Map<String,dynamic>)).toList());
}