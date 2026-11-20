import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_storage.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/login_request.dart';
import 'transaction_pin_setup_screen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository? repository;
  final ApiClient? apiClient;

  const LoginScreen({
    super.key,
    this.repository,
    this.apiClient,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SessionStorage _sessionStorage = SessionStorage();
  String _selectedTenantSlug = 'bancolombia';

  late AuthRepository _repository;
  late ApiClient _apiClient;
  bool _useMock = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Identidad visual de la entidad seleccionada en el login.
  Color get _bankPrimary {
    switch (_selectedTenantSlug) {
      case 'bancolombia':
        return const Color(0xFFFFD600);
      case 'banco-popular':
        return const Color(0xFF00843D);
      case 'nequi':
        return const Color(0xFFDA0081);
      case 'nu':
        return const Color(0xFF820AD1);
      default:
        return AppTheme.primary;
    }
  }

  Color get _bankForeground => _selectedTenantSlug == 'bancolombia' ? const Color(0xFF222222) : Colors.white;

  String get _selectedBankName {
    switch (_selectedTenantSlug) {
      case 'bancolombia':
        return 'Bancolombia';
      case 'banco-popular':
        return 'Banco Popular';
      case 'nequi':
        return 'Nequi';
      case 'nu':
        return 'Nu';
      default:
        return 'BankOS';
    }
  }

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _repository = widget.repository ?? ApiAuthRepository(apiClient: _apiClient);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMock() {
    setState(() {
      _useMock = !_useMock;
      _repository = _useMock ? MockAuthRepository() : ApiAuthRepository(apiClient: _apiClient);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_useMock ? 'Modo MOCK activado para Auth' : 'Modo API FastAPI activado'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = LoginRequest(
        tenantSlug: _selectedTenantSlug,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final response = await _repository.login(request);

      // La sesión real se persiste; los tokens MOCK nunca se guardan.
      if (_useMock) {
        await _sessionStorage.clearToken();
        ApiClient.setGlobalAuthToken(null);
        _apiClient.setAuthToken(null);
      } else {
        await _sessionStorage.saveToken(response.accessToken);
        _apiClient.setAuthToken(response.accessToken);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      // Verifica privilegio global en backend; ADMIN de un banco no es Platform Admin.
      final isPlatformAdmin = !_useMock
          ? ((await _apiClient.get('/users/me/platform-admin') as Map<String, dynamic>)['is_platform_admin'] == true)
          : false;
      Widget destination = isPlatformAdmin
          ? const AdminDashboardScreen()
          : const DashboardScreen();

      // Usuarios tenant, incluso admins bancarios, configuran PIN transaccional.
      if (!_useMock && !isPlatformAdmin) {
        final pinStatus = await _apiClient.get('/users/me/transaction-pin') as Map<String, dynamic>;
        final isPinConfigured = pinStatus['configured'] == true;
        if (!isPinConfigured) {
          destination = TransactionPinSetupScreen(
            apiClient: _apiClient,
            nextScreen: const DashboardScreen(),
          );
        } else {
          await _offerBiometricSetup();
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiException ? e.message : e.toString();
      });
    }
  }


  Future<void> _offerBiometricSetup() async {
    final biometric = BiometricService();
    final available = await biometric.isBiometricAvailable();
    if (!available || !mounted || await _sessionStorage.isBiometricEnabled()) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activar ${biometric.platformLabel}?'),
        content: Text('Puedes usar ${biometric.platformLabel} para desbloquear BankOS en próximos ingresos, sin escribir tu contraseña cada vez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activar')),
        ],
      ),
    );
    if (enable == true) {
      await _sessionStorage.setBiometricEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _toggleMock,
            icon: Icon(
              _useMock ? Icons.cloud_off : Icons.cloud_done,
              size: 16,
              color: _useMock ? Colors.amber.shade800 : AppTheme.success,
            ),
            label: Text(
              _useMock ? 'MOCK' : 'API',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _useMock ? Colors.amber.shade800 : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _bankPrimary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _bankPrimary.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.account_balance_rounded, color: _bankForeground, size: 40),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'BankOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Experiencia de $_selectedBankName · BankOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text('Institución Financiera (Tenant)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTenantSlug,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: const [
                          DropdownMenuItem(value: 'bancolombia', child: Text('Bancolombia')),
                          DropdownMenuItem(value: 'banco-popular', child: Text('Banco Popular')),
                          DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                          DropdownMenuItem(value: 'nu', child: Text('Nu')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedTenantSlug = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Correo electrónico', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'nombre@ejemplo.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
                      if (!value.contains('@')) return 'Ingresa un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text('Contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: _bankPrimary, foregroundColor: _bankForeground, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
