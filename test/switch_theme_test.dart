import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/theme/app_theme.dart';

/// Переключатель в обеих темах: включённое и выключенное состояния различаются цветом дорожки,
/// цветом ползунка и значком, а выключенный ползунок не сливается с дорожкой.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in {'светлая': lightTheme, 'тёмная': darkTheme}.entries) {
    test('${entry.key} тема: состояния переключателя различимы', () {
      final sw = entry.value.switchTheme;
      const on = {WidgetState.selected};
      const off = <WidgetState>{};

      expect(sw.trackColor!.resolve(on), AppColors.primary);
      expect(sw.trackColor!.resolve(off), isNot(AppColors.primary));
      expect(sw.thumbColor!.resolve(on), Colors.white);
      expect(sw.thumbColor!.resolve(off), isNot(Colors.white));

      // Выключенный ползунок не сливается с дорожкой, у выключенной дорожки есть контур
      expect(sw.thumbColor!.resolve(off), isNot(sw.trackColor!.resolve(off)));
      expect(sw.trackOutlineColor!.resolve(off), isNot(Colors.transparent));
      expect(sw.trackOutlineColor!.resolve(on), Colors.transparent);

      // Значки: галочка и крестик
      expect(sw.thumbIcon!.resolve(on)!.icon, Icons.check);
      expect(sw.thumbIcon!.resolve(off)!.icon, Icons.close);
    });
  }
}
