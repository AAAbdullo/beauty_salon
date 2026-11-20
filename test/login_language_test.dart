import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/l10n/app_locale.dart';
import 'package:beauty_salons/features/auth/auth_screen.dart';

/// Смена языка прямо на экране входа.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  setUp(() => AppLocale.instance.setLanguage(AppLanguage.ru));
  tearDown(() => AppLocale.instance.setLanguage(AppLanguage.ru));

  testWidgets('на экране входа можно выбрать язык; выбор применяется сразу', (tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        child: ListenableBuilder(
          listenable: AppLocale.instance,
          builder: (context, _) => MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: AuthScreen(onLoginSuccess: (_) {}),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget); // кнопка языка показывает текущий

    await tester.tap(find.text('Русский'));
    await settle(tester);
    expect(find.text("O'zbekcha (lotin)"), findsOneWidget);
    expect(find.text('Ўзбекча (кирилл)'), findsOneWidget);

    await tester.tap(find.text("O'zbekcha (lotin)"));
    await settle(tester);
    expect(AppLocale.instance.language, AppLanguage.uz);
    expect(find.text('Вход в систему'), findsNothing);
    expect(find.text("O'zbekcha"), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
