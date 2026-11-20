import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../dashboard/data/models/account_model.dart';
import '../../data/repositories/transaction_repository.dart';

class WithdrawalScreen extends StatefulWidget {
  final List<AccountModel> availableAccounts;
  final TransactionRepository repository;

  const WithdrawalScreen({
    super.key,
    required this.availableAccounts,
    required this.repository,
  });

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  AccountModel? _selectedAccount;
  bool _isSubmitting = false;
  String? _error;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    final activeAccounts =
        widget.availableAccounts.where((account) => account.isActive).toList();
    if (activeAccounts.isNotEmpty) {
      _selectedAccount = activeAccounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _invalidateIdempotencyKey() {
    _idempotencyKey = null;
  }

  Future<void> _confirmWithdrawal() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final availableBalance =
        double.tryParse(_selectedAccount!.balance) ?? 0;

    if (amount > availableBalance) {
      setState(() => _error = 'El monto supera el saldo disponible.');
      return;
    }

    final pinController = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar retiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cuenta: ${_selectedAccount!.accountNumberMasked}'),
            Text(
              'Monto: ${_amountController.text.trim()} '
              '${_selectedAccount!.currency}',
            ),
            const SizedBox(height: 16),
            const Text('Ingresa tu PIN de 4 dígitos:'),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (RegExp(r'^\\d{4}$').hasMatch(pinController.text)) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );

    if (approved != true) {
      pinController.dispose();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    _idempotencyKey ??=
        'withdraw-${DateTime.now().microsecondsSinceEpoch}';

    try {
      await widget.repository.withdraw(
        accountId: _selectedAccount!.id,
        amount: _amountController.text.trim(),
        currency: _selectedAccount!.currency,
        pin: pinController.text,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        idempotencyKey: _idempotencyKey!,
      );

      pinController.dispose();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      pinController.dispose();
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _error =
            'No se completó el retiro: $error. Puedes reintentar sin '
            'duplicar la operación.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccounts =
        widget.availableAccounts.where((account) => account.isActive).toList();

    if (activeAccounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Retirar fondos')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tienes cuentas activas disponibles para realizar retiros.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Retirar fondos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Cuenta de origen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<AccountModel>(
                initialValue: _selectedAccount,
                items: activeAccounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account,
                        child: Text(
                          '${account.displayName} • '
                          '${account.accountNumberMasked}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (account) {
                  setState(() {
                    _selectedAccount = account;
                    _error = null;
                    _invalidateIdempotencyKey();
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              if (_selectedAccount != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Saldo disponible: ${CurrencyFormatter.format(
                    _selectedAccount!.balance,
                    _selectedAccount!.currency,
                  )}',
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Monto a retirar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _invalidateIdempotencyKey(),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: _selectedAccount?.currency,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto válido mayor a cero.';
                  }
                  final balance =
                      double.tryParse(_selectedAccount?.balance ?? '') ?? 0;
                  if (amount > balance) {
                    return 'El monto supera el saldo disponible.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Concepto (opcional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLength: 200,
                onChanged: (_) => _invalidateIdempotencyKey(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej. Retiro en efectivo',
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmWithdrawal,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmar retiro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
