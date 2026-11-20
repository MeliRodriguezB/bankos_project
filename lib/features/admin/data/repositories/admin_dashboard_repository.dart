import '../../../../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';
class AdminDashboardRepository {
 final ApiClient client;
 AdminDashboardRepository({ApiClient? client}):client=client??ApiClient();
 Future<AdminDashboardModel> getDashboard() async {
  final response=await client.get('/admin/dashboard');
  return AdminDashboardModel.fromJson(response as Map<String,dynamic>);
 }
}