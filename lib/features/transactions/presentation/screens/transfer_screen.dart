import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../dashboard/data/models/account_model.dart';
import '../../data/models/transfer_quote_model.dart';
import '../../data/repositories/transaction_repository.dart';

class TransferScreen extends StatefulWidget {
  final List<AccountModel> availableAccounts;
  final TransactionRepository repository;

  const TransferScreen({
    super.key,
    required this.availableAccounts,
    required this.repository,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  late AccountModel _selectedAccount;
  final _destinationController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoadingQuote = false;
  bool _isTransferring = false;
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
    _destinationController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // A new payload must use a new key; failed retries of the same payload keep theirs.
  void _invalidateIdempotencyKey() {
    _currentIdempotencyKey = null;
  }

  Future<void> _requestQuoteAndConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoadingQuote = true;
      _errorMessage = null;
    });

    try {
      final quote = await widget.repository.getQuote(
        sourceAccountId: _selectedAccount.id,
        destinationAccountNumber: _destinationController.text.trim(),
        amount: _amountController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoadingQuote = false);
        _showConfirmationDialog(quote);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showConfirmationDialog(TransferQuoteModel quote) {
    final pinController = TextEditingController();
    // Generar idempotency key única para este intento de transferencia
    _currentIdempotencyKey ??= 'idem-${DateTime.now().microsecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confirmar Transferencia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Resumen Financiero Pre-Transacción
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildQuoteRow('Cuenta Origen', _selectedAccount.accountNumberMasked),
                    _buildQuoteRow('Cuenta Destino', quote.destinationAccountMasked),
                    _buildQuoteRow('Monto a transferir', '${quote.amountToDebit} ${quote.sourceCurrency}'),
                    _buildQuoteRow('Comisión bancaria', '${quote.feeAmount} ${quote.sourceCurrency}'),
                    if (quote.hasCurrencyConversion) ...[
                      _buildQuoteRow('Tasa de cambio', '1 ${quote.sourceCurrency} = ${quote.exchangeRate} ${quote.destinationCurrency}'),
                      _buildQuoteRow('Monto final recibido', '${quote.amountToCredit} ${quote.destinationCurrency}', isBold: true),
                    ],
                    const Divider(height: 18),
                    _buildQuoteRow('Total a debitar', '${quote.totalDebited} ${quote.sourceCurrency}', isBold: true, highlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Doble Factor: Ingreso de PIN
              const Text(
                'Ingresa tu PIN de 4 dígitos para autorizar:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isTransferring
                    ? null
                    : () async {
                        if (pinController.text.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ingresa tu PIN completo de 4 dígitos.')),
                          );
                          return;
                        }

                        setModalState(() => _isTransferring = true);
                        try {
                          await widget.repository.transfer(
                            sourceAccountId: _selectedAccount.id,
                            destinationAccountNumber: _destinationController.text.trim(),
                            amount: _amountController.text.trim(),
                            currency: _selectedAccount.currency,
                            pin: pinController.text,
                            description: _descController.text.isEmpty ? null : _descController.text,
                            idempotencyKey: _currentIdempotencyKey!,
                          );

                          if (mounted) {
                            Navigator.pop(ctx); // Cerrar modal
                            Navigator.pop(context, true); // Volver al dashboard con éxito
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Transferencia completada con éxito!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => _isTransferring = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e. Puedes reintentar con la misma llave.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                child: _isTransferring
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Autorizar y Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: highlight ? AppTheme.primary : AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.availableAccounts.any((a) => a.isActive)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva Transferencia')),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tienes cuentas activas disponibles para realizar transferencias.'))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Transferencia')),
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

              // Selector de cuenta origen
              const Text('Cuenta Origen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                          _invalidateIdempotencyKey();
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Cuenta destino
              const Text('Número de Cuenta Destino', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _destinationController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _invalidateIdempotencyKey(),
                decoration: InputDecoration(
                  hintText: 'Ej. 1002348922',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la cuenta destino' : null,
              ),
              const SizedBox(height: 20),

              // Monto a transferir
              const Text('Monto a Transferir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _invalidateIdempotencyKey(),
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

              // Concepto
              const Text('Concepto (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                onChanged: (_) => _invalidateIdempotencyKey(),
                decoration: InputDecoration(
                  hintText: 'Ej. Pago de arriendo',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoadingQuote ? null : _requestQuoteAndConfirm,
                child: _isLoadingQuote
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Continuar a Confirmación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
