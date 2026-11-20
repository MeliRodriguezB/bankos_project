import '../../../../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';
import '../models/tenant_config_model.dart';
class AdminDashboardRepository {
 final ApiClient client;
 AdminDashboardRepository({ApiClient? client}):client=client??ApiClient();
 Future<List<AdminAccountModel>> getAccounts() async {
  final response=await client.get('/admin/accounts');
  return (response as List<dynamic>).map((e)=>AdminAccountModel.fromJson(e as Map<String,dynamic>)).toList();
 }

 Future<TenantConfigModel> getTenantConfig() async {
  final response=await client.get('/tenant/config');
  return TenantConfigModel.fromJson(response as Map<String,dynamic>);
 }
 Future<TenantConfigModel> updateTenantConfig(TenantConfigModel config) async {
  final response=await client.patch('/tenant/config', config.toUpdateJson());
  return TenantConfigModel.fromJson(response as Map<String,dynamic>);
 }
 Future<AdminDashboardModel> getDashboard() async {
  final response=await client.get('/admin/dashboard');
  return AdminDashboardModel.fromJson(response as Map<String,dynamic>);
 }
}