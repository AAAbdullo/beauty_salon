import 'package:flutter/services.dart';
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

  static const weekDaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const monthsShort = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  static const monthsGenitive = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Подпись дня визита: «Сегодня», «Завтра», «Вчера» или «12 ноя»
  static String dayLabel(DateTime date, {DateTime? now}) {
    final today = _dayOnly(now ?? DateTime.now());
    final diff = _dayOnly(date).difference(today).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';
    if (diff == -1) return 'Вчера';
    final yearSuffix = date.year != today.year ? ' ${date.year}' : '';
    return '${date.day} ${monthsShort[date.month - 1]}$yearSuffix';
  }

  /// Время «HH:mm»
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// Полная дата «12 ноября 2026»
  static String fullDate(DateTime date) => '${date.day} ${monthsGenitive[date.month - 1]} ${date.year}';

  /// Русское склонение по числу: plural(1, 'отзыв', 'отзыва', 'отзывов') → «1 отзыв»
  static String plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    final word = (mod10 == 1 && mod100 != 11)
        ? one
        : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
        ? few
        : many;
    return '$n $word';
  }

  static String reviews(int n) => plural(n, 'отзыв', 'отзыва', 'отзывов');
  static String years(int n) => plural(n, 'год', 'года', 'лет');

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

/// Маска локальной части узбекского номера: «XX XXX XX XX» (9 цифр после +998).
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  /// Количество цифр в локальной части номера
  static const digitsCount = 9;

  static String format(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > digitsCount ? digits.substring(0, digitsCount) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(clipped[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
