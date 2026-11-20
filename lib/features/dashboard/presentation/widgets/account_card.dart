import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/account_model.dart';
import 'status_badge.dart';

class AccountCard extends StatelessWidget {
  final AccountModel account;
  final Color bankColor;
  final bool isBalanceHidden;
  final VoidCallback onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.bankColor,
    required this.isBalanceHidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBalance = isBalanceHidden
        ? '••••••••'
        : CurrencyFormatter.format(account.balance, account.currency);
    final isInactive = !account.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: bankColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isInactive
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: account.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          account.accountNumberMasked,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo disponible',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedBalance,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isInactive
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppTheme.textSecondary),
                      ],
                    ),
                    if (isInactive) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Cuenta desactivada. No admite nuevas operaciones.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }
}
