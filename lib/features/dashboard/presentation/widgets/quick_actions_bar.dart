import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class QuickActionsBar extends StatelessWidget {
  final VoidCallback? onTransfer;
  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onHistory;

  const QuickActionsBar({
    super.key,
    this.onTransfer,
    this.onDeposit,
    this.onWithdraw,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          context,
          icon: Icons.send_rounded,
          label: 'Transferir',
          onTap: onTransfer ?? () => _showComingSoon(context, 'Transferencias (Persona 3)'),
        ),
        _buildActionButton(
          context,
          icon: Icons.add_circle_outline_rounded,
          label: 'Depositar',
          onTap: onDeposit ?? () => _showComingSoon(context, 'Depósitos (Persona 3)'),
        ),
        _buildActionButton(
          context,
          icon: Icons.arrow_circle_down_rounded,
          label: 'Retirar',
          onTap: onWithdraw ?? () => _showComingSoon(context, 'Retiros (Persona 3)'),
        ),
        _buildActionButton(
          context,
          icon: Icons.history_rounded,
          label: 'Historial',
          onTap: onHistory ?? () => _showComingSoon(context, 'Historial (Persona 3)'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Acceso al flujo de $moduleName'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
