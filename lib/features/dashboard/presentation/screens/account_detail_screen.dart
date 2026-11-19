import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/account_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../widgets/status_badge.dart';

class AccountDetailScreen extends StatefulWidget {
  final AccountModel account;
  final DashboardRepository repository;

  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.repository,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late AccountModel _account;
  bool _isProcessing = false;
  bool _showFullAccountNumber = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desactivar esta cuenta?'),
        content: const Text(
          'La cuenta pasará a estado INACTIVA mediante borrado lógico.\n\n'
          '• No se podrán realizar transferencias, depósitos ni retiros.\n'
          '• Se preservará todo el historial de movimientos para auditoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar cuenta'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await widget.repository.deactivateAccount(_account.id);
      if (mounted) {
        setState(() {
          _account = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La cuenta ha sido desactivada con éxito.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desactivar la cuenta: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');
    final formattedDate = dateFormat.format(_account.createdAt.toLocal());
    final visibleNumber = _showFullAccountNumber
        ? _account.accountNumber
        : _account.accountNumberMasked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Cuenta'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Tarjeta principal con saldo y estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _account.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      StatusBadge(status: _account.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saldo disponible',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(_account.balance, _account.currency),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.getCurrencyName(_account.currency),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Datos de la cuenta
            const Text(
              'Información bancaria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Número de cuenta',
                    value: visibleNumber,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showFullAccountNumber
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _showFullAccountNumber = !_showFullAccountNumber;
                            });
                          },
                          tooltip: 'Mostrar número completo',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppTheme.accent,
                          ),
                          onPressed: () => _copyToClipboard(
                            _account.accountNumber,
                            'Número de cuenta',
                          ),
                          tooltip: 'Copiar número',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  _buildDetailRow(
                    label: 'Moneda de operación',
                    value: _account.currency,
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  _buildDetailRow(
                    label: 'Fecha de apertura',
                    value: formattedDate,
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  _buildDetailRow(
                    label: 'ID de cuenta (Sistema)',
                    value: _account.id,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.accent),
                      onPressed: () => _copyToClipboard(_account.id, 'ID de cuenta'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón de Soft Delete (Desactivar cuenta)
            if (_account.isActive)
              Center(
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        onPressed: _handleDeactivate,
                        icon: const Icon(Icons.block_rounded, size: 18),
                        label: const Text(
                          'Desactivar esta cuenta',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
