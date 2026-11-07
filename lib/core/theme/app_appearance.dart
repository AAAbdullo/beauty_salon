import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Выбранный пользователем режим оформления (хранится в памяти; после подключения бэкенда/хранилища — сохранять).
class AppAppearance extends ChangeNotifier {
  AppAppearance._();
  static final AppAppearance instance = AppAppearance._();

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Тёмная ли палитра при выбранном режиме и системной яркости [platform]
  bool resolveDark(Brightness platform) => switch (_mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => platform == Brightness.dark,
  };

  /// Применяет палитру. Возвращает `true`, если она изменилась (тогда дерево нужно перестроить).
  static bool applyPalette(bool dark) {
    if (AppColors.isDark == dark) return false;
    AppColors.isDark = dark;
    return true;
  }

  /// Перестраивает все живые виджеты: палитра [AppColors] — не часть `Theme`, поэтому сама их не обновит.
  static void rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}
