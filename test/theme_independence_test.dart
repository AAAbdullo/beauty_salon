import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/theme/app_theme.dart';

/// Регрессия: `lightTheme` — глобальная переменная, которая считается при первом обращении.
/// Если приложение запущено в тёмной теме, «светлая» тема не должна получить тёмные цвета.
/// Тест лежит в отдельном файле, чтобы `lightTheme` впервые вычислялась именно здесь, при тёмной палитре.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => AppColors.isDark = false);

  test('светлая тема остаётся светлой, даже если впервые собрана при включённой тёмной палитре', () {
    AppColors.isDark = true;

    expect(lightTheme.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(lightTheme.colorScheme.surface, AppColors.lightSurface);
    expect(lightTheme.colorScheme.onSurface, AppColors.lightInk);
    expect(lightTheme.colorScheme.primaryContainer, AppColors.lightPrimaryTint);
    expect(lightTheme.textTheme.bodyMedium?.color, AppColors.lightInk);

    expect(darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
    expect(darkTheme.colorScheme.onSurface, AppColors.darkInk);
  });
}
