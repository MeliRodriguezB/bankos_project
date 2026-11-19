import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formatea un saldo en String o numérico al formato estándar de la divisa.
  /// 
  /// Regla financiera:
  /// Esta función solo se encarga de la PRESENTACIÓN visual.
  /// Nunca realiza sumas, restas ni conversiones cambiarias en el cliente.
  static String format(String balanceStr, String currency) {
    try {
      final double value = double.tryParse(balanceStr) ?? 0.0;
      final NumberFormat formatter;

      switch (currency.toUpperCase()) {
        case 'COP':
          formatter = NumberFormat.currency(
            symbol: '\$',
            decimalDigits: 2,
            locale: 'es_CO',
          );
          break;
        case 'USD':
          formatter = NumberFormat.currency(
            symbol: 'US\$',
            decimalDigits: 2,
            locale: 'en_US',
          );
          break;
        case 'EUR':
          formatter = NumberFormat.currency(
            symbol: '€',
            decimalDigits: 2,
            locale: 'de_DE',
          );
          break;
        default:
          formatter = NumberFormat.currency(
            symbol: '$currency ',
            decimalDigits: 2,
          );
      }

      return formatter.format(value);
    } catch (_) {
      return '$balanceStr $currency';
    }
  }

  /// Retorna un símbolo o etiqueta amigable según el código ISO
  static String getCurrencyName(String currency) {
    switch (currency.toUpperCase()) {
      case 'COP':
        return 'Pesos Colombianos';
      case 'USD':
        return 'Dólares Americanos';
      case 'EUR':
        return 'Euros';
      default:
        return currency;
    }
  }
}
