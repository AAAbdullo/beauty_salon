import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/features/my_bookings/my_bookings_screen.dart';

/// «Мои записи»: пометка про срок отмены и точное время, до которого запись можно отменить.
/// Время: среда 11 ноября 2026, 10:00. b-001 — через 80 минут (отмена закрыта), b-005 — завтра 08:00.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    AppStateService().resetSession();
  });

  tearDown(() {
    AppClock.reset();
    AppStateService().resetSession();
  });

  testWidgets('вкладка «Активные»: пометка про 2 часа и время, до которого можно отменить', (tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: MyBookingsScreen(onBookNew: () {}),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Отменить или перенести запись можно не позднее чем за 2 часа до её начала.'), findsOneWidget);
    // b-005: визит завтра в 08:00 → отменить можно до 06:00 завтрашнего дня
    expect(find.text('Отменить запись (до Завтра, 06:00)'), findsOneWidget);
    // b-001: до визита 80 минут → отмена закрыта
    expect(find.text('Отмена заблокирована (< 2 ч до визита)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
