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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            context,
            icon: Icons.arrow_outward_rounded,
            label: 'Transferir',
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
            onTap: onTransfer ?? () => _showComingSoon(context, 'Transferencias'),
          ),
          _buildActionButton(
            context,
            icon: Icons.south_west_rounded,
            label: 'Depositar',
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF10B981).withOpacity(0.35),
            onTap: onDeposit ?? () => _showComingSoon(context, 'Depósitos'),
          ),
          _buildActionButton(
            context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Retirar',
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF7C3AED).withOpacity(0.35),
            onTap: onWithdraw ?? () => _showComingSoon(context, 'Retiros'),
          ),
          _buildActionButton(
            context,
            icon: Icons.receipt_long_rounded,
            label: 'Historial',
            gradient: const LinearGradient(
              colors: [Color(0xFF334155), Color(0xFF475569)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF334155).withOpacity(0.35),
            onTap: onHistory ?? () => _showComingSoon(context, 'Historial'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 0.1,
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
