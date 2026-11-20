import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/presentation/screens/deposit_screen.dart';
import '../../../transactions/presentation/screens/history_screen.dart';
import '../../../transactions/presentation/screens/transfer_screen.dart';
import '../../../transactions/presentation/screens/withdrawal_screen.dart';
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
  String? _brandingPrimary;

  // Branding por tenant desde backend; fallback local si el endpoint no está disponible.
  Color get _bankColor {
    final configured = _brandingPrimary;
    if (configured != null && configured.startsWith('#') && configured.length == 7) {
      final parsed = int.tryParse(configured.substring(1), radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
    final tenant = (_dashboardData?.tenantName ?? '').toLowerCase();
    if (tenant.contains('bancolombia')) return const Color(0xFF007A4B);
    if (tenant.contains('popular')) return const Color(0xFFB5121B);
    if (tenant.contains('nequi')) return const Color(0xFFDA0081);
    if (tenant.contains('nu')) return const Color(0xFF820AD1);
    return AppTheme.accent;
  }

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
      _brandingPrimary = null;
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
      String? brandingColor;
      if (!_useMock) {
        try {
          final branding = await ApiClient().get('/users/me/bank-branding') as Map<String, dynamic>;
          brandingColor = branding['primary_color']?.toString();
        } catch (_) {
          // El branding es opcional para renderizar; fallback a la paleta por nombre.
        }
      }
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _brandingPrimary = brandingColor;
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

  Future<void> _handleLogout() async {
    // Limpia el token en memoria y el almacenamiento seguro.
    ApiClient.setGlobalAuthToken(null);
    await SessionStorage().clearToken();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _bankColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'BankOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Panel Principal'),
          ],
        ),
        actions: [
          // Switch Mock / Real API
          Tooltip(
            message: _useMock ? 'Cambiar a Backend FastAPI' : 'Cambiar a Datos Mock',
            child: TextButton.icon(
              onPressed: _toggleRepositorySource,
              icon: Icon(
                _useMock ? Icons.cloud_off : Icons.cloud_done,
                size: 16,
                color: _useMock ? Colors.amber.shade800 : AppTheme.success,
              ),
              label: Text(
                _useMock ? 'MOCK' : 'API',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _useMock ? Colors.amber.shade800 : AppTheme.success,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _buildBody(),
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
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 380 ? 12 : 20, vertical: 16),
        children: [
          // 1. Cabecera con resumen financiero por divisa y tenant
          BalanceHeaderCard(
            userName: data.userName,
            tenantName: data.tenantName,
            bankColor: _bankColor,
            balances: data.balancesByCurrency,
            isBalanceHidden: _isBalanceHidden,
            onToggleVisibility: () {
              setState(() => _isBalanceHidden = !_isBalanceHidden);
            },
          ),
          const SizedBox(height: 24),

          // 2. Barra de accesos directos vinculada con Persona 3
          QuickActionsBar(
            bankColor: _bankColor,
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
              if (success == true) {
                _fetchDashboard();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Transferencia completada con éxito!'), backgroundColor: AppTheme.success),
                );
              }
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
              if (success == true) {
                _fetchDashboard();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Depósito acreditado exitosamente.'), backgroundColor: AppTheme.success),
                );
              }
            },
            onWithdraw: () async {
              final activeAccounts = data.accounts.where((a) => a.isActive).toList();
              if (activeAccounts.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No tienes cuentas activas para retirar.')),
                );
                return;
              }
              final success = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => WithdrawalScreen(
                    availableAccounts: activeAccounts,
                    repository: _txRepository,
                  ),
                ),
              );
              if (success == true) {
                _fetchDashboard();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retiro completado exitosamente.'), backgroundColor: AppTheme.success),
                );
              }
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

          // 3. Listado de cuentas bancarias
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mis Cuentas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${data.accounts.length} ${data.accounts.length == 1 ? 'cuenta' : 'cuentas'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tarjetas de cuentas
          ...data.accounts.map((acc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AccountCard(
                  account: acc,
                  bankColor: _bankColor,
                  isBalanceHidden: _isBalanceHidden,
                  onTap: () => _openAccountDetail(acc),
                ),
              )),
        ],
      ),
    );
  }
}
