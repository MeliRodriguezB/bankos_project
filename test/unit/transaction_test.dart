import 'package:flutter_test/flutter_test.dart';
import 'package:bankos_project/features/transactions/data/models/transaction_model.dart';
import 'package:bankos_project/features/transactions/data/models/transfer_quote_model.dart';
import 'package:bankos_project/features/transactions/data/repositories/transaction_repository.dart';

void main() {
  group('Transaction Tests (Persona 3)', () {
    test('TransactionModel detecta cobro de comisiones y conversión de divisas', () {
      final json = {
        'id': 'tx-123',
        'type': 'TRANSFER',
        'amount': '100.00',
        'currency': 'USD',
        'fee_amount': '1.00',
        'exchange_rate': '4000.000000',
        'converted_amount': '400000.00',
        'destination_currency': 'COP',
        'status': 'COMPLETED',
        'created_at': '2026-11-19T10:00:00.000Z',
      };

      final tx = TransactionModel.fromJson(json);
      expect(tx.id, 'tx-123');
      expect(tx.hasFee, isTrue);
      expect(tx.hasConversion, isTrue);
      expect(tx.status, 'COMPLETED');
    });

    test('TransferQuoteModel deserializa pre-desglose con conversión correctamente', () {
      final json = {
        'source_currency': 'USD',
        'destination_currency': 'COP',
        'amount_to_debit': '100.00',
        'fee_amount': '1.00',
        'total_debited': '101.00',
        'exchange_rate': '4000.000000',
        'amount_to_credit': '400000.00',
        'has_currency_conversion': true,
        'destination_account_masked': '•••• 8922',
      };

      final quote = TransferQuoteModel.fromJson(json);
      expect(quote.totalDebited, '101.00');
      expect(quote.amountToCredit, '400000.00');
      expect(quote.hasCurrencyConversion, isTrue);
    });

    test('MockTransactionRepository realiza cotización y transferencia con PIN', () async {
      final repo = MockTransactionRepository();

      final quote = await repo.getQuote(
        sourceAccountId: 'acc-901',
        destinationAccountNumber: '1002348922',
        amount: '50000.00',
      );
      expect(quote.totalDebited, '51500.00');

      final tx = await repo.transfer(
        sourceAccountId: 'acc-901',
        destinationAccountNumber: '1002348922',
        amount: '50000.00',
        currency: 'COP',
        pin: '1234',
        idempotencyKey: 'idem-test-123',
      );

      expect(tx.status, 'COMPLETED');
      expect(tx.idempotencyKey, 'idem-test-123');
    });

    test('MockTransactionRepository rechaza transferencia con PIN incorrecto', () async {
      final repo = MockTransactionRepository();
      expect(
        () => repo.transfer(
          sourceAccountId: 'acc-901',
          destinationAccountNumber: '1002348922',
          amount: '50000.00',
          currency: 'COP',
          pin: '9999',
          idempotencyKey: 'idem-test-456',
        ),
        throwsA(anything),
      );
    });
  });
}
