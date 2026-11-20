import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Pantalla obligatoria para configurar el PIN transaccional del usuario.
/// El backend verifica la contraseña actual y almacena el PIN como hash.
class TransactionPinSetupScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Widget nextScreen;

  const TransactionPinSetupScreen({
    super.key,
    required this.apiClient,
    required this.nextScreen,
  });

  @override
  State<TransactionPinSetupScreen> createState() => _TransactionPinSetupScreenState();
}

class _TransactionPinSetupScreenState extends State<TransactionPinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.put('/users/me/transaction-pin', {
        'current_password': _passwordController.text,
        'pin': _pinController.text,
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'No fue posible configurar el PIN. Intenta nuevamente.';
        _loading = false;
      });
    }
  }

  String? _validatePin(String? value) {
    if (value == null || value.length != 4) return 'Ingresa exactamente 4 dígitos';
    if (!RegExp(r'^\d{4}.hasMatch(value)) return 'El PIN solo puede contener números';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Configura tu PIN'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security_rounded, size: 56, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text('Protege tus transacciones', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 10),
                  const Text('Crea un PIN de 4 dígitos que utilizarás para autorizar retiros y transferencias.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña actual', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña actual' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Nuevo PIN (4 dígitos)',
                      prefixIcon: const Icon(Icons.pin),
                      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                      counterText: '',
                    ),
                    validator: _validatePin,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPinController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: 'Confirma tu PIN', prefixIcon: Icon(Icons.check_circle_outline), counterText: ''),
                    validator: (value) {
                      final pinError = _validatePin(value);
                      if (pinError != null) return pinError;
                      if (value != _pinController.text) return 'Los PIN no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _savePin,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Configurar PIN'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tu PIN se almacena protegido y no se guarda en texto plano.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
).hasMatch(value)) return 'El PIN solo puede contener números';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Configura tu PIN'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security_rounded, size: 56, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text('Protege tus transacciones', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 10),
                  const Text('Crea un PIN de 4 dígitos que utilizarás para autorizar retiros y transferencias.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña actual', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña actual' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Nuevo PIN (4 dígitos)',
                      prefixIcon: const Icon(Icons.pin),
                      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                      counterText: '',
                    ),
                    validator: _validatePin,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPinController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: 'Confirma tu PIN', prefixIcon: Icon(Icons.check_circle_outline), counterText: ''),
                    validator: (value) {
                      final pinError = _validatePin(value);
                      if (pinError != null) return pinError;
                      if (value != _pinController.text) return 'Los PIN no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _savePin,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Configurar PIN'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tu PIN se almacena protegido y no se guarda en texto plano.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
