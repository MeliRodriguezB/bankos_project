import '../../../../core/network/api_client.dart';
import '../models/account_model.dart';
import '../models/dashboard_model.dart';
import 'dashboard_repository.dart';

class ApiDashboardRepository implements DashboardRepository {
  final ApiClient _apiClient;

  ApiDashboardRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<DashboardModel> getDashboard() async {
    final response = await _apiClient.get('/dashboard');
    return DashboardModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<AccountModel>> getAccounts() async {
    final response = await _apiClient.get('/accounts');
    final list = response as List<dynamic>;
    return list
        .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AccountModel> getAccountDetail(String accountId) async {
    final response = await _apiClient.get('/accounts/$accountId');
    return AccountModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AccountModel> deactivateAccount(String accountId) async {
    final response = await _apiClient.patch('/accounts/$accountId/deactivate');
    return AccountModel.fromJson(response as Map<String, dynamic>);
  }
}
