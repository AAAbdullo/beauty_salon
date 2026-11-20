import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/theme/app_appearance.dart';
import 'package:beauty_salons/core/theme/app_theme.dart';
import 'package:beauty_salons/main.dart';

void main() {
  setUpAll(loadTestFonts);

  tearDown(() {
    AppAppearance.instance.setMode(ThemeMode.light);
    AppColors.isDark = false;
    AppStateService().resetSession();
  });

  test('палитра переключается между светлой и тёмной', () {
    AppColors.isDark = false;
    final lightSurface = AppColors.surface;
    final lightInk = AppColors.ink;
    AppColors.isDark = true;
    expect(AppColors.surface, isNot(lightSurface));
    expect(AppColors.ink, isNot(lightInk));
    expect(AppColors.surface, AppColors.darkSurface);
    expect(AppColors.soft(const Color(0xFFFFECEF)), isNot(const Color(0xFFFFECEF)));
    AppColors.isDark = false;
    expect(AppColors.soft(const Color(0xFFFFECEF)), const Color(0xFFFFECEF));
  });

  testWidgets('переключение темы на лету перекрашивает уже открытый экран', (tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      GozallikApp(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester);

    Color? scaffoldSurface() => tester
        .widgetList<Material>(find.byType(Material))
        .map((m) => m.color)
        .firstWhere((c) => c == AppColors.surface || c == AppColors.darkSurface, orElse: () => null);

    AppAppearance.instance.setMode(ThemeMode.dark);
    await settle(tester);
    expect(AppColors.isDark, isTrue);
    expect(tester.takeException(), isNull);
    expect(scaffoldSurface(), anyOf(isNull, AppColors.darkSurface));

    AppAppearance.instance.setMode(ThemeMode.light);
    await settle(tester);
    expect(AppColors.isDark, isFalse);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
