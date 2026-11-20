import 'package:flutter/material.dart' hide Text;

import '../../l10n/app_locale.dart';
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';
import 'app_sheet.dart';

/// Название языка на нём самом (не переводится)
String languageLabel(AppLanguage language) => switch (language) {
  AppLanguage.uz => "O'zbekcha",
  AppLanguage.uzCyrl => 'Ўзбекча',
  AppLanguage.ru => 'Русский',
};

/// Окно выбора языка: используется в настройках и на экране входа
void showLanguagePicker(BuildContext context) {
  // ТЗ: uz-Latn, uz-Cyrl, ru
  const languages = [
    ("O'zbekcha (lotin)", AppLanguage.uz),
    ('Ўзбекча (кирилл)', AppLanguage.uzCyrl),
    ('Русский', AppLanguage.ru),
  ];
  showAppSheet<void>(
    context: context,
    title: 'Язык приложения',
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: languages
          .map(
            (l) => ListTile(
              title: Text(l.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: l.$2 == AppLocale.instance.language ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                AppLocale.instance.setLanguage(l.$2);
                Navigator.pop(ctx);
              },
            ),
          )
          .toList(),
    ),
  );
}
