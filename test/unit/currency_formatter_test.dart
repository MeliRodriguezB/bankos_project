import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bankos_project/core/utils/currency_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO', null);
  });

  group('CurrencyFormatter Tests', () {
    test('Formatea correctamente saldo en Pesos Colombianos (COP)', () {
      final formatted = CurrencyFormatter.format('2450000.00', 'COP');
      expect(formatted.contains('2.450.000'), isTrue);
      expect(formatted.contains('\$'), isTrue);
    });

    test('Formatea correctamente saldo en Dólares (USD)', () {
      final formatted = CurrencyFormatter.format('350.50', 'USD');
      expect(formatted.contains('350.50'), isTrue);
      expect(formatted.contains('US\$'), isTrue);
    });

    test('Maneja entradas con valores 0 o nulos sin lanzar excepción', () {
      final formatted = CurrencyFormatter.format('0.00', 'COP');
      expect(formatted.isNotEmpty, isTrue);
    });

    test('Obtiene el nombre correcto de cada divisa', () {
      expect(CurrencyFormatter.getCurrencyName('COP'), 'Pesos Colombianos');
      expect(CurrencyFormatter.getCurrencyName('USD'), 'Dólares Americanos');
      expect(CurrencyFormatter.getCurrencyName('EUR'), 'Euros');
    });
  });
}
