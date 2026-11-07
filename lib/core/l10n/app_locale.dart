import 'package:flutter/foundation.dart';
import 'uz_strings.dart';

/// Язык интерфейса. Тексты в коде написаны по-русски; при выборе узбекского они переводятся в момент показа
/// через [tr] по словарю [uzExact] / [uzTemplates] (динамические фразы — по шаблонам с подстановкой).
enum AppLanguage { ru, uz }

class AppLocale extends ChangeNotifier {
  AppLocale._();
  static final AppLocale instance = AppLocale._();

  AppLanguage _language = AppLanguage.ru;
  AppLanguage get language => _language;

  /// Быстрая проверка для [tr]
  static bool get isUz => instance._language == AppLanguage.uz;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    _cache.clear();
    notifyListeners();
  }
}

final _cyrillic = RegExp(r'[А-Яа-яЁё]');
final _cache = <String, String>{};

/// Переводит русский текст на выбранный язык. Для русского и неизвестных фраз возвращает текст как есть.
String tr(String s) {
  if (!AppLocale.isUz || s.isEmpty || !_cyrillic.hasMatch(s)) return s;
  final cached = _cache[s];
  if (cached != null) return cached;
  final result = _translate(s) ?? s;
  if (_cache.length > 4000) _cache.clear();
  return _cache[s] = result;
}

/// Переведено ли [s] полностью (для проверки словаря); `false` — осталась русская часть.
@visibleForTesting
bool isFullyTranslated(String s) => !_cyrillic.hasMatch(tr(s));

/// Названия языков не переводятся
const _keepAsIs = {'Русский', 'Ўзбекча (кирилл)'};

String? _translate(String s) {
  if (_keepAsIs.contains(s)) return null;
  final exact = uzExact[s];
  if (exact != null) return exact;

  // Края из пробелов не входят в ключ словаря
  final trimmed = s.trim();
  if (trimmed != s) {
    if (trimmed.isEmpty) return null;
    final inner = _translate(trimmed);
    if (inner == null) return null;
    final start = s.indexOf(trimmed);
    return s.substring(0, start) + inner + s.substring(start + trimmed.length);
  }

  final byTemplate = _byTemplate(s);
  if (byTemplate != null) return byTemplate;

  final date = _byDate(s);
  if (date != null) return date;

  // Составные тексты: строки, предложения, части через « · » и «, »
  final lines = s.split('\n');
  if (lines.length > 1) {
    final joined = _translateParts(lines);
    if (joined != null) return joined.join('\n');
  }
  final dots = s.split(' · ');
  if (dots.length > 1) {
    final joined = _translateParts(dots);
    if (joined != null) return joined.join(' · ');
  }
  final sentences = s.split(RegExp(r'(?<=[.!?])\s+'));
  if (sentences.length > 1) {
    final joined = _translateParts(sentences);
    if (joined != null) return joined.join(' ');
  }
  final commas = s.split(', ');
  if (commas.length > 1) {
    final joined = _translateParts(commas);
    if (joined != null) return joined.join(', ');
  }

  // Имена людей (в т.ч. введённые пользователем): «Алена», «Дилноза Юсупова» — транслитерация
  if (_nameRegex.hasMatch(s)) return _transliterate(s);

  // Текст со скобками: «4.8 (126 отзывов)»
  final bracket = RegExp(r'^(.*?)\((.+)\)(.*)$', dotAll: true).firstMatch(s);
  if (bracket != null) {
    final inner = _translate(bracket.group(2)!);
    if (inner != null) {
      final before = bracket.group(1)!, after = bracket.group(3)!;
      final b = before.trim().isEmpty ? null : _translate(before.trim());
      return '${b == null ? before : before.replaceFirst(before.trim(), b)}($inner)$after';
    }
  }
  return null;
}

/// Переводит каждую часть; `null`, если не переведена ни одна.
List<String>? _translateParts(List<String> parts) {
  var any = false;
  final out = <String>[];
  for (final p in parts) {
    final t = p.trim();
    final r = t.isEmpty ? null : _translate(t);
    if (r != null) any = true;
    out.add(r == null ? p : p.replaceFirst(t, r));
  }
  return any ? out : null;
}

// ── Шаблоны с подстановкой ──────────────────────────────────────────────────

class _Template {
  final RegExp regex;
  final String target;
  final int staticLength;
  _Template(this.regex, this.target, this.staticLength);
}

final List<_Template> _templates = _buildTemplates();

List<_Template> _buildTemplates() {
  final list = <_Template>[];
  uzTemplates.forEach((source, target) {
    final buf = StringBuffer('^');
    var staticLength = 0;
    var last = 0;
    for (final m in RegExp(r'\{\d+\}').allMatches(source)) {
      final text = source.substring(last, m.start);
      staticLength += text.length;
      buf
        ..write(RegExp.escape(text))
        ..write('(.+?)');
      last = m.end;
    }
    final tail = source.substring(last);
    staticLength += tail.length;
    buf
      ..write(RegExp.escape(tail))
      ..write(r'$');
    list.add(_Template(RegExp(buf.toString(), dotAll: true), target, staticLength));
  });
  list.sort((a, b) => b.staticLength.compareTo(a.staticLength));
  return list;
}

String? _byTemplate(String s) {
  for (final t in _templates) {
    final m = t.regex.firstMatch(s);
    if (m == null) continue;
    return t.target.replaceAllMapped(RegExp(r'\{(\d+)\}'), (g) {
      final i = int.parse(g.group(1)!);
      if (i + 1 > m.groupCount) return g.group(0)!;
      final value = m.group(i + 1) ?? '';
      return _translate(value) ?? value;
    });
  }
  return null;
}

// ── Даты «12 ноя», «12 ноября 2026» ────────────────────────────────────────

final _dateRegex = RegExp(
  r'^(\d{1,2}) (янв|фев|мар|апр|мая|июн|июл|авг|сен|окт|ноя|дек|января|февраля|марта|апреля|июня|июля|августа|сентября|октября|ноября|декабря)( \d{4})?$',
);

String? _byDate(String s) {
  final m = _dateRegex.firstMatch(s);
  if (m == null) return null;
  final month = uzExact[m.group(2)!] ?? m.group(2)!;
  return '${m.group(1)} $month${m.group(3) ?? ''}';
}

// ── Транслитерация имён ─────────────────────────────────────────────────────

final _nameRegex = RegExp(r'^[А-ЯЁ][а-яё]+(?:[ -][А-ЯЁ][а-яё]*\.?){0,2}$');

const _translitMap = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'yo',
  'ж': 'j',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'x',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'sh',
  'ъ': "'",
  'ы': 'i',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

String _transliterate(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    final mapped = _translitMap[lower];
    if (mapped == null) {
      out.write(ch);
    } else if (ch != lower && mapped.isNotEmpty) {
      out.write(mapped[0].toUpperCase() + mapped.substring(1));
    } else {
      out.write(mapped);
    }
  }
  return out.toString();
}
