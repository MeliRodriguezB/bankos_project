import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/tenant_config_model.dart';
import '../../data/repositories/admin_dashboard_repository.dart';

class TenantSettingsScreen extends StatefulWidget {
  final AdminDashboardRepository repository;

  const TenantSettingsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<TenantSettingsScreen> createState() => _TenantSettingsScreenState();
}

class _TenantSettingsScreenState extends State<TenantSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxTransferController = TextEditingController();
  final _feePercentController = TextEditingController();
  final _primaryCurrencyController = TextEditingController();
  final _supportedCurrenciesController = TextEditingController();
  final _transferFeesController = TextEditingController();
  final _exchangeRatesController = TextEditingController();
  final _webhookController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _maxTransferController.dispose();
    _feePercentController.dispose();
    _primaryCurrencyController.dispose();
    _supportedCurrenciesController.dispose();
    _transferFeesController.dispose();
    _exchangeRatesController.dispose();
    _webhookController.dispose();
    super.dispose();
  }

  void _applyConfig(TenantConfigModel config) {
    _maxTransferController.text = config.maxTransferAmount;
    _feePercentController.text = config.transferFeePercent;
    _primaryCurrencyController.text = config.primaryCurrency;
    _supportedCurrenciesController.text = config.supportedCurrencies.join(', ');
    _transferFeesController.text = const JsonEncoder.withIndent('  ').convert(config.transferFees);
    _exchangeRatesController.text = const JsonEncoder.withIndent('  ').convert(config.exchangeRates);
    _webhookController.text = config.webhookUrl ?? '';
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await widget.repository.getTenantConfig();
      if (mounted) _applyConfig(config);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, String> _parseCurrencyMap(String value, String label) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw FormatException('$label debe ser un objeto JSON.');
    }
    return decoded.map(
      (key, amount) => MapEntry(
        key.toString().toUpperCase(),
        amount.toString(),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final currencies = _supportedCurrenciesController.text
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      final config = TenantConfigModel(
        maxTransferAmount: _maxTransferController.text.trim(),
        transferFees: _parseCurrencyMap(_transferFeesController.text, 'Comisiones'),
        transferFeePercent: _feePercentController.text.trim(),
        primaryCurrency: _primaryCurrencyController.text.trim().toUpperCase(),
        supportedCurrencies: currencies,
        exchangeRates: _parseCurrencyMap(_exchangeRatesController.text, 'Tasas de cambio'),
        webhookUrl: _webhookController.text.trim().isEmpty
            ? null
            : _webhookController.text.trim(),
      );

      final saved = await widget.repository.updateTenantConfig(config);
      if (!mounted) return;
      _applyConfig(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración institucional actualizada.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración institucional'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _maxTransferController.text.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadConfig,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Políticas de transferencias',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Límite máximo por transferencia',
                        controller: _maxTransferController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      _field(
                        label: 'Comisión porcentual (ej. 0.005)',
                        controller: _feePercentController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monedas y tasas',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Moneda principal',
                        controller: _primaryCurrencyController,
                        hint: 'COP',
                      ),
                      _field(
                        label: 'Monedas soportadas (separadas por coma)',
                        controller: _supportedCurrenciesController,
                        hint: 'COP, USD',
                      ),
                      _field(
                        label: 'Comisiones fijas por moneda (JSON)',
                        controller: _transferFeesController,
                        maxLines: 4,
                        hint: '{"COP":"1000.00","USD":"1.00"}',
                      ),
                      _field(
                        label: 'Tasas de cambio por par (JSON)',
                        controller: _exchangeRatesController,
                        maxLines: 5,
                        hint: '{"COP/USD":"0.00025","USD/COP":"4000.00"}',
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Integraciones',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'URL del webhook (opcional)',
                        controller: _webhookController,
                        hint: 'https://hooks.example.test/bankos',
                      ),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppTheme.error)),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _saveConfig,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Guardando...' : 'Guardar configuración'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
