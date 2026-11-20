import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/network/api_client.dart';
import 'core/network/session_storage.dart';
import 'features/auth/presentation/screens/biometric_lock_screen.dart';
import 'features/auth/presentation/screens/transaction_pin_setup_screen.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';

class BankOsApp extends StatefulWidget {
  const BankOsApp({super.key});

  @override
  State<BankOsApp> createState() => _BankOsAppState();
}

class _BankOsAppState extends State<BankOsApp> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_CO', null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SessionGate(),
    );
  }
}

/// Revisa si hay una sesión guardada y si el JWT no ha expirado.
/// La validación de firma y autorización sigue siendo responsabilidad del backend.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<Widget> _initialRoute;

  @override
  void initState() {
    super.initState();
    _initialRoute = _restoreSession();
  }

  Future<Widget> _restoreSession() async {
    final storage = SessionStorage();
    final token = await storage.readToken();
    if (token == null || token.isEmpty || !_isTokenNotExpired(token)) {
      await storage.clearToken();
      ApiClient.setGlobalAuthToken(null);
      return const LoginScreen();
    }

    ApiClient.setGlobalAuthToken(token);
    // El privilegio global se confirma contra backend; un rol ADMIN de tenant
    // no debe abrir el panel de administración de toda la plataforma.
    bool isPlatformAdmin;
    try {
      final status = await ApiClient().get('/users/me/platform-admin') as Map<String, dynamic>;
      isPlatformAdmin = status['is_platform_admin'] == true;
    } catch (_) {
      await storage.clearToken();
      ApiClient.setGlobalAuthToken(null);
      return const LoginScreen();
    }

    // Solo los Platform Admin exentos de PIN; administradores de banco son usuarios tenant.
    if (!isPlatformAdmin) {
      try {
        final pinStatus = await ApiClient().get('/users/me/transaction-pin') as Map<String, dynamic>;
        if (pinStatus['configured'] != true) {
          return TransactionPinSetupScreen(
            apiClient: ApiClient(),
            nextScreen: const DashboardScreen(),
          );
        }
      } catch (_) {
        await storage.clearToken();
        ApiClient.setGlobalAuthToken(null);
        return const LoginScreen();
      }
    }

    if (await storage.isBiometricEnabled()) {
      return const BiometricLockScreen();
    }
    return isPlatformAdmin ? const AdminDashboardScreen() : const DashboardScreen();
  }

  bool _isTokenNotExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false;
      return DateTime.now().millisecondsSinceEpoch < exp * 1000;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialRoute,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
