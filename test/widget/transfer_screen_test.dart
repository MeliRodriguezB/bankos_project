import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bankos_project/core/network/api_client.dart';
import 'package:bankos_project/core/theme/app_theme.dart';
import 'package:bankos_project/features/dashboard/data/models/account_model.dart';
import 'package:bankos_project/features/transactions/data/models/transaction_model.dart';
import 'package:bankos_project/features/transactions/data/models/transfer_quote_model.dart';
import 'package:bankos_project/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bankos_project/features/transactions/presentation/screens/transfer_screen.dart';

class _RetryingTransferRepository implements TransactionRepository {
  final List<String> idempotencyKeys = [];

  @override
  Future<TransferQuoteModel> getQuote({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
  }) async {
    return TransferQuoteModel(
      sourceCurrency: 'COP',
      destinationCurrency: 'COP',
      amountToDebit: amount,
      feeAmount: '1500.00',
      totalDebited: (double.parse(amount) + 1500).toStringAsFixed(2),
      exchangeRate: '1.000000',
      amountToCredit: amount,
      hasCurrencyConversion: false,
      destinationAccountMasked: '•••• 8922',
    );
  }

  @override
  Future<TransactionModel> transfer({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    throw ApiException(
      statusCode: 0,
      message: 'Simulated network interruption',
    );
  }

  @override
  Future<TransactionModel> deposit({
    required String accountId,
    required String amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TransactionModel> withdraw({
    required String accountId,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TransactionModel>> getHistory({
    String? accountId,
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async => [];
}

void main() {
  testWidgets(
    'transfer keeps the same idempotency key for retries and rotates it when payload changes',
    (WidgetTester tester) async {
      final repository = _RetryingTransferRepository();
      final account = AccountModel(
        id: 'source-account',
        accountNumber: '1002348911',
        accountNumberMasked: '•••• 8911',
        alias: 'Cuenta principal',
        balance: '50000.00',
        currency: 'COP',
        status: 'ACTIVE',
        createdAt: DateTime.utc(2026, 11, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransferScreen(
            availableAccounts: [account],
            repository: repository,
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '1002348922');
      await tester.enterText(fields.at(1), '1000.00');
      await tester.tap(find.text('Continuar a Confirmación'));
      await tester.pumpAndSettle();

      Future<void> attemptTransfer() async {
        await tester.enterText(find.byType(TextField).last, '1234');
        await tester.tap(find.text('Autorizar y Enviar'));
        await tester.pumpAndSettle();
      }

      await attemptTransfer();
      expect(repository.idempotencyKeys, hasLength(1));

      // A retry of the unchanged payload must reuse the original key.
      await attemptTransfer();
      expect(repository.idempotencyKeys, hasLength(2));
      expect(
        repository.idempotencyKeys[1],
        repository.idempotencyKeys[0],
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Editing the amount changes the payload and must rotate the key.
      await tester.enterText(fields.at(1), '2000.00');
      await tester.tap(find.text('Continuar a Confirmación'));
      await tester.pumpAndSettle();
      await attemptTransfer();

      expect(repository.idempotencyKeys, hasLength(3));
      expect(repository.idempotencyKeys[2], isNot(repository.idempotencyKeys[0]));
    },
  );
}
