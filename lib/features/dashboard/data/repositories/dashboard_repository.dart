import '../models/account_model.dart';
import '../models/dashboard_model.dart';

abstract class DashboardRepository {
  /// Obtiene el resumen financiero completo para la pantalla de inicio
  Future<DashboardModel> getDashboard();

  /// Obtiene la lista de cuentas asociadas al usuario autenticado
  Future<List<AccountModel>> getAccounts();

  /// Obtiene los detalles de una cuenta específica
  Future<AccountModel> getAccountDetail(String accountId);

  /// Desactiva una cuenta (borrado lógico)
  Future<AccountModel> deactivateAccount(String accountId);
}
