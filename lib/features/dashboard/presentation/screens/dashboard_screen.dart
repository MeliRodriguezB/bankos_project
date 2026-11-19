import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/presentation/screens/deposit_screen.dart';
import '../../../transactions/presentation/screens/history_screen.dart';
import '../../../transactions/presentation/screens/transfer_screen.dart';
import '../../data/models/account_model.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/api_dashboard_repository.dart';
import '../../data/repositories/mock_dashboard_repository.dart';
import '../widgets/account_card.dart';
import '../widgets/balance_header_card.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/state_views.dart';
import 'account_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardRepository? repository;
  final TransactionRepository? transactionRepository;

  const DashboardScreen({
    super.key,
    this.repository,
    this.transactionRepository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardRepository _repository;
  late TransactionRepository _txRepository;
  bool _useMock = false;

  DashboardModel? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _correlationId;
  bool _isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiDashboardRepository();
    _txRepository = widget.transactionRepository ?? ApiTransactionRepository();
    _fetchDashboard();
  }

  void _toggleRepositorySource() {
    setState(() {
      _useMock = !_useMock;
      _repository = _useMock ? MockDashboardRepository() : ApiDashboardRepository();
      _txRepository = _useMock ? MockTransactionRepository() : ApiTransactionRepository();
      _isLoading = true;
    });
    _fetchDashboard();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useMock
              ? 'Modo DEMO activado: usando datos Mock locales.'
              : 'Modo API activado: conectando a FastAPI en localhost:8000.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _correlationId = null;
    });

    try {
      final data = await _repository.getDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _openAccountDetail(AccountModel account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(
          account: account,
          repository: _repository,
        ),
      ),
    );
    _fetchDashboard();
  }

  void _handleLogout() {
    // Limpieza de sesión
    ApiClient.setGlobalAuthToken(null);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'BankOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Panel Principal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Switch Mock / Real API estilizado en cápsula moderna
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleRepositorySource,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _useMock ? Colors.amber.shade800 : AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _useMock ? 'MOCK' : 'API',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _useMock ? Colors.amber.shade900 : AppTheme.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón de Cerrar Sesión
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const DashboardLoadingView();
    }

    if (_errorMessage != null) {
      return DashboardErrorView(
        message: _errorMessage!,
        correlationId: _correlationId,
        onRetry: _fetchDashboard,
      );
    }

    final data = _dashboardData;
    if (data == null || data.accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: DashboardEmptyView(onRefresh: _fetchDashboard),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      color: AppTheme.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Cabecera con resumen financiero por divisa y tenant
          BalanceHeaderCard(
            userName: data.userName,
            tenantName: data.tenantName,
            balances: data.balancesByCurrency,
            isBalanceHidden: _isBalanceHidden,
            onToggleVisibility: () {
              setState(() => _isBalanceHidden = !_isBalanceHidden);
            },
          ),
          const SizedBox(height: 24),

          // 2. Barra de accesos directos moderna
          QuickActionsBar(
            onTransfer: () async {
              final activeAccounts = data.accounts.where((a) => a.isActive).toList();
              if (activeAccounts.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No tienes cuentas activas para transferir.')),
                );
                return;
              }
              final success = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => TransferScreen(
                    availableAccounts: activeAccounts,
                    repository: _txRepository,
                  ),
                ),
              );
              if (success == true) _fetchDashboard();
            },
            onDeposit: () async {
              final activeAccounts = data.accounts.where((a) => a.isActive).toList();
              final success = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DepositScreen(
                    availableAccounts: activeAccounts,
                    repository: _txRepository,
                  ),
                ),
              );
              if (success == true) _fetchDashboard();
            },
            onWithdraw: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Usa los cajeros automáticos o la pantalla de transferencia para mover fondos.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onHistory: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(repository: _txRepository),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          // 3. Cabecera de la sección "Mis Cuentas"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Mis Cuentas',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data.accounts.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${data.accounts.length} ${data.accounts.length == 1 ? 'cuenta' : 'cuentas'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjetas de cuentas bancarias
          ...data.accounts.map((acc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AccountCard(
                  account: acc,
                  isBalanceHidden: _isBalanceHidden,
                  onTap: () => _openAccountDetail(acc),
                ),
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
