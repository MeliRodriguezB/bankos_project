import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../dashboard/data/models/account_model.dart';
import '../../data/repositories/transaction_repository.dart';

class DepositScreen extends StatefulWidget {
  final List<AccountModel> availableAccounts;
  final TransactionRepository repository;

  const DepositScreen({
    super.key,
    required this.availableAccounts,
    required this.repository,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  late AccountModel _selectedAccount;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  String? _currentIdempotencyKey;

  @override
  void initState() {
    super.initState();
    final activeAccounts = widget.availableAccounts.where((a) => a.isActive).toList();
    if (activeAccounts.isNotEmpty) _selectedAccount = activeAccounts.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      _currentIdempotencyKey ??= 'idem-dep-${DateTime.now().millisecondsSinceEpoch}';
      await widget.repository.deposit(
        accountId: _selectedAccount.id,
        amount: _amountController.text.trim(),
        currency: _selectedAccount.currency,
        description: _descController.text.isEmpty ? null : _descController.text,
        idempotencyKey: _currentIdempotencyKey!,
      );

      if (mounted) {
        // El resultado true permite que la pantalla anterior actualice los saldos.
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.availableAccounts.any((a) => a.isActive)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Depositar Fondos')),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tienes cuentas activas disponibles para recibir depósitos.'))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Depositar Fondos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Cuenta a Abonar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AccountModel>(
                    value: _selectedAccount,
                    isExpanded: true,
                    items: widget.availableAccounts
                        .where((a) => a.isActive)
                        .map((acc) => DropdownMenuItem(
                              value: acc,
                              child: Text('${acc.displayName} (${acc.accountNumberMasked}) - ${CurrencyFormatter.format(acc.balance, acc.currency)}'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedAccount = val;
                          _currentIdempotencyKey = null;
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Monto a Depositar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _currentIdempotencyKey = null,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: _selectedAccount.currency,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa el monto';
                  final num = double.tryParse(v);
                  if (num == null || num <= 0) return 'El monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text('Motivo / Referencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                onChanged: (_) => _currentIdempotencyKey = null,
                decoration: InputDecoration(
                  hintText: 'Ej. Nómina quincenal',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isProcessing ? null : _handleDeposit,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Confirmar Depósito'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
