class AdminDashboardModel {
  final int banksTotal, banksActive, usersTotal, accountsTotal, accountsActive, transactionsTotal;
  final String transactionVolume;
  const AdminDashboardModel({required this.banksTotal, required this.banksActive, required this.usersTotal, required this.accountsTotal, required this.accountsActive, required this.transactionsTotal, required this.transactionVolume});
  factory AdminDashboardModel.fromJson(Map<String,dynamic> j)=>AdminDashboardModel(
    banksTotal:(j['banks_total'] as num?)?.toInt()??0,
    banksActive:(j['banks_active'] as num?)?.toInt()??0,
    usersTotal:(j['users_total'] as num?)?.toInt()??0,
    accountsTotal:(j['accounts_total'] as num?)?.toInt()??0,
    accountsActive:(j['accounts_active'] as num?)?.toInt()??0,
    transactionsTotal:(j['transactions_total'] as num?)?.toInt()??0,
    transactionVolume:j['transaction_volume']?.toString()??'0');
}
class AdminBankModel {
  final String id,name,slug,status,primaryColor,secondaryColor,accentColor;
  const AdminBankModel({required this.id,required this.name,required this.slug,required this.status,required this.primaryColor,required this.secondaryColor,required this.accentColor});
  factory AdminBankModel.fromJson(Map<String,dynamic> j){
    final b=j['branding'] as Map<String,dynamic>? ?? {};
    return AdminBankModel(id:j['id']?.toString()??'',name:j['name']?.toString()??'',slug:j['slug']?.toString()??'',status:j['status']?.toString()??'INACTIVE',primaryColor:b['primary_color']?.toString()??'#145DA0',secondaryColor:b['secondary_color']?.toString()??'#FFFFFF',accentColor:b['accent_color']?.toString()??'#F4B942');
  }
}
class AdminAccountModel {
  final String id,accountNumberMasked,alias,balance,currency,status,ownerName,ownerEmail,bank;
  const AdminAccountModel({required this.id,required this.accountNumberMasked,required this.alias,required this.balance,required this.currency,required this.status,required this.ownerName,required this.ownerEmail,required this.bank});
  factory AdminAccountModel.fromJson(Map<String,dynamic> j)=>AdminAccountModel(id:j['id']?.toString()??'',accountNumberMasked:j['account_number_masked']?.toString()??j['account_number']?.toString()??'',alias:j['alias']?.toString()??'Cuenta',balance:j['balance']?.toString()??'0',currency:j['currency']?.toString()??'',status:j['status']?.toString()??'',ownerName:j['owner_name']?.toString()??'Titular',ownerEmail:j['owner_email']?.toString()??'',bank:j['bank']?.toString()??'Banco');
}
