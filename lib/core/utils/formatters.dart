import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat('#,###', 'ru_RU');

  /// Форматирует сумму в сумах, например: "1 240 000 сум"
  static String formatSum(num amount) {
    final formatted = _currencyFormat.format(amount).replaceAll(',', ' ');
    return '$formatted сум';
  }

  /// Форматирует цену в кредитах, например: "34 кр."
  static String formatCredits(int credits) {
    return '$credits кр.';
  }

  /// Форматирует номер телефона Узбекистана в читаемый вид +998 (90) 123-45-67
  static String formatPhone(String rawPhone) {
    final clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 12 && clean.startsWith('998')) {
      final code = clean.substring(3, 5);
      final p1 = clean.substring(5, 8);
      final p2 = clean.substring(8, 10);
      final p3 = clean.substring(10, 12);
      return '+998 ($code) $p1-$p2-$p3';
    }
    return rawPhone;
  }
}
