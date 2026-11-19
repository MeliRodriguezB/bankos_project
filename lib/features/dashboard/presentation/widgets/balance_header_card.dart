import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/balance_summary_model.dart';

class BalanceHeaderCard extends StatelessWidget {
  final String userName;
  final String tenantName;
  final List<BalanceSummaryModel> balances;
  final bool isBalanceHidden;
  final VoidCallback onToggleVisibility;

  const BalanceHeaderCard({
    super.key,
    required this.userName,
    required this.tenantName,
    required this.balances,
    required this.isBalanceHidden,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Tenant e icono de visibilidad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge de la institución financiera (Tenant)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tenantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
                tooltip: isBalanceHidden ? 'Mostrar saldos' : 'Ocultar saldos',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Saludo al usuario
          Text(
            'Hola, $userName',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Desglose de saldos por divisa
          if (balances.isEmpty)
            const Text(
              '\$ 0.00 COP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: balances.map((b) {
                final formatted = isBalanceHidden
                    ? '••••••••'
                    : CurrencyFormatter.format(b.totalBalance, b.currency);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${b.activeAccountsCount} ${b.activeAccountsCount == 1 ? 'cuenta' : 'cuentas'})',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
