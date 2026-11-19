import 'package:flutter_test/flutter_test.dart';
import 'package:bankos_project/features/dashboard/data/models/account_model.dart';

void main() {
  group('AccountModel Tests', () {
    test('Serializa y deserializa JSON correctamente', () {
      final json = {
        'id': 'acc-123',
        'account_number': '1002348911',
        'account_number_masked': '•••• 8911',
        'alias': 'Cuenta Principal',
        'balance': '1500000.00',
        'currency': 'COP',
        'status': 'ACTIVE',
        'created_at': '2026-01-15T10:30:00.000Z',
      };

      final account = AccountModel.fromJson(json);

      expect(account.id, 'acc-123');
      expect(account.accountNumber, '1002348911');
      expect(account.accountNumberMasked, '•••• 8911');
      expect(account.alias, 'Cuenta Principal');
      expect(account.balance, '1500000.00');
      expect(account.currency, 'COP');
      expect(account.status, 'ACTIVE');
      expect(account.isActive, isTrue);
      expect(account.isInactive, isFalse);
    });

    test('Identifica cuentas inactivas correctamente (Soft Delete)', () {
      final json = {
        'id': 'acc-999',
        'account_number': '9999999999',
        'account_number_masked': '•••• 9999',
        'balance': '0.00',
        'currency': 'COP',
        'status': 'INACTIVE',
      };

      final account = AccountModel.fromJson(json);

      expect(account.isActive, isFalse);
      expect(account.isInactive, isTrue);
    });
  });
}
