import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/network/session_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/biometric_service.dart';
import 'login_screen.dart';
import 'transaction_pin_setup_screen.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

/// Screen shown when a saved session is protected by device biometrics.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometric = BiometricService();
  bool _busy = false;
  String? _error;

  bool _hasAdminRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final roles = payload['roles'] as List<dynamic>? ?? [];
      return roles.map((r) => r.toString().toUpperCase()).contains('ADMIN');
    } catch (_) {
      return false;
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    final success = await _biometric.authenticate();
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      final token = await SessionStorage().readToken();
      if (!mounted) return;
      final isAdmin = _hasAdminRole(token ?? '');
      Widget destination = isAdmin ? const AdminDashboardScreen() : const DashboardScreen();
      if (!isAdmin) {
        try {
          final pinStatus = await ApiClient().get('/users/me/transaction-pin') as Map<String, dynamic>;
          if (pinStatus['configured'] != true) {
            destination = TransactionPinSetupScreen(
              apiClient: ApiClient(),
              nextScreen: const DashboardScreen(),
            );
          }
        } catch (_) {
          setState(() => _error = 'No se pudo verificar la configuración del PIN. Cierra sesión e ingresa nuevamente.');
          return;
        }
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      setState(() => _error = 'No fue posible validar la biometría. Inténtalo de nuevo.');
    }
  }

  Future<void> _logout() async {
    await SessionStorage().clearToken();
    await SessionStorage().setBiometricEnabled(false);
    ApiClient.setGlobalAuthToken(null);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fingerprint, size: 76),
          const SizedBox(height: 16),
          const Text('BankOS está protegido', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Confirma tu identidad para desbloquear tu sesión.'),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _unlock,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_open),
            label: const Text('Desbloquear'),
          ),
          TextButton(onPressed: _logout, child: const Text('Ingresar con contraseña')),
        ]),
      ),
    ),
  );
}
