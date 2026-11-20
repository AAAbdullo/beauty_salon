import 'dart:math';

/// Генератор UUID v4 (случайный). Нужен для id записей и ключей идемпотентности.
class Uuid {
  Uuid._();

  static final Random _random = Random.secure();

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // версия 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // вариант RFC 4122
    String hex(int from, int to) => bytes.sublist(from, to).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
