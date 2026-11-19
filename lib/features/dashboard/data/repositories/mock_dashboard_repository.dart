import '../models/account_model.dart';
import '../models/balance_summary_model.dart';
import '../models/dashboard_model.dart';
import 'dashboard_repository.dart';

/// Repositorio con datos simulados (Mock) para pruebas de UI y desarrollo desacoplado.
/// Mantenido en archivo separado y claramente identificado según los lineamientos del equipo.
class MockDashboardRepository implements DashboardRepository {
  List<AccountModel> _mockAccounts = [
    AccountModel(
      id: 'acc-901',
      accountNumber: '1002348911',
      accountNumberMasked: '•••• 8911',
      alias: 'Cuenta de Ahorros Principal',
      balance: '2450000.00',
      currency: 'COP',
      status: 'ACTIVE',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    AccountModel(
      id: 'acc-902',
      accountNumber: '1002348922',
      accountNumberMasked: '•••• 8922',
      alias: 'Fondo de Emergencia',
      balance: '450000.00',
      currency: 'COP',
      status: 'ACTIVE',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    AccountModel(
      id: 'acc-903',
      accountNumber: '2005541100',
      accountNumberMasked: '•••• 1100',
      alias: 'Ahorro Dólares',
      balance: '350.00',
      currency: 'USD',
      status: 'ACTIVE',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    AccountModel(
      id: 'acc-904',
      accountNumber: '1002348999',
      accountNumberMasked: '•••• 8999',
      alias: 'Cuenta Nómina Anterior',
      balance: '0.00',
      currency: 'COP',
      status: 'INACTIVE', // Para probar borrado lógico en la UI
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
    ),
  ];

  @override
  Future<DashboardModel> getDashboard() async {
    // Simular latencia de red
    await Future.delayed(const Duration(milliseconds: 600));

    return DashboardModel(
      userId: 'usr-dev-101',
      userName: 'Carlos Mendoza',
      userEmail: 'carlos.mendoza@banco-demo.com',
      tenantId: 'tenant-coop-01',
      tenantName: 'Cooperativa Financiera Futuro',
      balancesByCurrency: [
        BalanceSummaryModel(
          currency: 'COP',
          totalBalance: '2900000.00',
          activeAccountsCount: 2,
        ),
        BalanceSummaryModel(
          currency: 'USD',
          totalBalance: '350.00',
          activeAccountsCount: 1,
        ),
      ],
      accounts: List.unmodifiable(_mockAccounts),
    );
  }

  @override
  Future<List<AccountModel>> getAccounts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_mockAccounts);
  }

  @override
  Future<AccountModel> getAccountDetail(String accountId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final account = _mockAccounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('Cuenta no encontrada'),
    );
    return account;
  }

  @override
  Future<AccountModel> deactivateAccount(String accountId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockAccounts.indexWhere((a) => a.id == accountId);
    if (index == -1) throw Exception('Cuenta no encontrada');

    final old = _mockAccounts[index];
    final updated = AccountModel(
      id: old.id,
      accountNumber: old.accountNumber,
      accountNumberMasked: old.accountNumberMasked,
      alias: old.alias,
      balance: old.balance,
      currency: old.currency,
      status: 'INACTIVE',
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );

    _mockAccounts[index] = updated;
    return updated;
  }
}
