import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/account_model.dart';
import 'status_badge.dart';

class AccountCard extends StatelessWidget {
  final AccountModel account;
  final bool isBalanceHidden;
  final VoidCallback onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.isBalanceHidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBalance = isBalanceHidden
        ? '••••••••'
        : CurrencyFormatter.format(account.balance, account.currency);

    final isInactive = !account.isActive;
    final isUsd = account.currency.toUpperCase() == 'USD';

    // Color temático de la cuenta
    final Color accentColor = isInactive
        ? AppTheme.textMuted
        : (isUsd ? const Color(0xFFF59E0B) : AppTheme.success);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInactive ? AppTheme.border : AppTheme.borderHighlight.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Ícono estilizado, Alias y Badges
                Row(
                  children: [
                    // Contenedor de ícono temático
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isInactive
                            ? Icons.pause_circle_outline_rounded
                            : (isUsd ? Icons.monetization_on_rounded : Icons.account_balance_wallet_rounded),
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Título y tipo de divisa
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isInactive ? AppTheme.textSecondary : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  account.currency,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.contactless_rounded, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                account.accountNumberMasked,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Badge de Estado (ACTIVA / INACTIVA)
                    StatusBadge(status: account.status),
                  ],
                ),
                const SizedBox(height: 18),

                // Separador sutil
                Container(
                  height: 1,
                  color: AppTheme.border.withOpacity(0.7),
                ),
                const SizedBox(height: 14),

                // Fila 3: Saldo y Chevron de acceso
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo disponible',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formattedBalance,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isInactive ? AppTheme.textSecondary : AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    // Botón circular sutil con chevron
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Alerta informativa si la cuenta está inactiva (Soft Delete)
                if (isInactive) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cuenta desactivada. No admite nuevas operaciones.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
