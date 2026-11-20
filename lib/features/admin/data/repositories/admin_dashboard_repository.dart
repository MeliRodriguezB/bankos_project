import '../../../../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';
class AdminDashboardRepository {
 final ApiClient client;
 AdminDashboardRepository({ApiClient? client}):client=client??ApiClient();
 Future<List<AdminAccountModel>> getAccounts() async {
  final response=await client.get('/admin/accounts');
  return (response as List<dynamic>).map((e)=>AdminAccountModel.fromJson(e as Map<String,dynamic>)).toList();
 }
 Future<List<AdminBankModel>> getBanks() async {
  final response=await client.get('/admin/banks');
  return (response as List<dynamic>).map((e)=>AdminBankModel.fromJson(e as Map<String,dynamic>)).toList();
 }
 Future<AdminDashboardModel> getDashboard() async {
  final response=await client.get('/admin/dashboard');
  return AdminDashboardModel.fromJson(response as Map<String,dynamic>);
 }
 Future<AdminBankModel> createBank({required String name,required String slug}) async {
  final response=await client.post('/admin/banks',{'name':name,'slug':slug});
  return AdminBankModel.fromJson(response as Map<String,dynamic>);
 }
 Future<AdminBankModel> updateBank(AdminBankModel bank,{String? status}) async {
  final response=await client.patch('/admin/banks/${bank.id}',{'status':status??bank.status});
  return AdminBankModel.fromJson(response as Map<String,dynamic>);
 }
}
