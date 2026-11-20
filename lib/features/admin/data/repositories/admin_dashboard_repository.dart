import '../../../../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';
class AdminDashboardRepository {
 final ApiClient client;
 AdminDashboardRepository({ApiClient? client}):client=client??ApiClient();
 Future<List<AdminAccountModel>> getAccounts() async {
  final response=await client.get('/admin/accounts');
  return (response as List<dynamic>).map((e)=>AdminAccountModel.fromJson(e as Map<String,dynamic>)).toList();
 }
 Future<AdminDashboardModel> getDashboard() async {
  final response=await client.get('/admin/dashboard');
  return AdminDashboardModel.fromJson(response as Map<String,dynamic>);
 }
}