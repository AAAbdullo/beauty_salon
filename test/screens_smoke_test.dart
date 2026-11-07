import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/models/booking_draft.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/features/auth/auth_screen.dart';
import 'package:beauty_salons/features/auth/onboarding_registration_screen.dart';
import 'package:beauty_salons/features/booking/booking_screen.dart';
import 'package:beauty_salons/features/booking/payment_screen.dart';
import 'package:beauty_salons/features/client_home/client_home_screen.dart';
import 'package:beauty_salons/features/favorites/favorites_screen.dart';
import 'package:beauty_salons/features/master_cabinet/dashboard/master_dashboard_screen.dart';
import 'package:beauty_salons/features/master_cabinet/earnings/master_earnings_screen.dart';
import 'package:beauty_salons/features/master_cabinet/profile/master_account_screen.dart';
import 'package:beauty_salons/features/master_cabinet/schedule/master_schedule_screen.dart';
import 'package:beauty_salons/features/my_bookings/my_bookings_screen.dart';
import 'package:beauty_salons/features/notifications/notifications_screen.dart';
import 'package:beauty_salons/features/profile_settings/client_profile_screen.dart';
import 'package:beauty_salons/features/profile_settings/settings_screen.dart';
import 'package:beauty_salons/features/salon_detail/master_profile_screen.dart';
import 'package:beauty_salons/features/salon_detail/salon_detail_screen.dart';
import 'package:beauty_salons/features/subscription_credits/credits_screen.dart';

/// Смоук-тест: каждый экран строится без исключений и переполнений
/// на обычном (390×844) и узком (360×690) телефоне.
void main() {
  void noop() {}

  // Реальные метрики шрифта вместо тестового «квадратного» — иначе переполнения ложные
  setUpAll(() async {
    // flutter_tester лежит внутри SDK: <flutter>/bin/cache/artifacts/engine/...
    final exe = Platform.resolvedExecutable;
    final cacheIndex = exe.indexOf('${Platform.pathSeparator}bin${Platform.pathSeparator}cache');
    if (cacheIndex == -1) return;
    final fontsDir = '${exe.substring(0, cacheIndex)}/bin/cache/artifacts/material_fonts';
    if (!File('$fontsDir/Roboto-Regular.ttf').existsSync()) return;
    final loader = FontLoader('Roboto');
    for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
      final bytes = File('$fontsDir/Roboto-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(File('$fontsDir/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
    await icons.load();
  });

  final screens = <String, Widget Function()>{
    'Auth': () => AuthScreen(onLoginSuccess: (_) {}),
    'Onboarding': () => OnboardingRegistrationScreen(onCompleted: noop, onBackToLogin: noop),
    'Home': () => ClientHomeScreen(
      onOpenMap: noop,
      onSalonTap: (_) {},
      onMasterTap: (_) {},
      onOpenFavorites: noop,
      onOpenNotifications: noop,
      onOpenCredits: noop,
      onOpenProfile: noop,
    ),
    // s-001 Nur Beauty (есть мастера), s-005 Zara Beauty Lab (без мастеров и кредитов), s-008 Elite Barber
    // и несуществующий id — должен показаться экран «не найдено», а не чужой салон
    for (final salonId in ['s-001', 's-005', 's-008', 's-unknown'])
      'Salon $salonId': () => SalonDetailScreen(
        salonId: salonId,
        onBack: noop,
        onBook: ({masterId, service}) {},
        onMasterTap: (_) {},
        onShowOnMap: (_) {},
      ),
    for (final masterId in ['m-001', 'm-unknown'])
      'Master $masterId': () => MasterProfileScreen(masterId: masterId, onBack: noop, onBookMaster: (_) {}),
    for (final salonId in ['s-001', 's-005', 's-004', 's-unknown'])
      'Booking $salonId': () => BookingScreen(salonId: salonId, onBack: noop, onConfirm: (_, _) {}),
    'Payment': () => PaymentScreen(
      draft: BookingDraft(
        salonId: 's-001',
        salonName: 'Nur Beauty',
        serviceId: 'm-001-s1',
        serviceName: 'Комбинированный маникюр + гель-лак',
        durationLabel: '60 мин',
        masterId: 'm-001',
        masterName: 'Алена',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        credits: 34,
        sumPrice: 150000,
      ),
      onBack: noop,
      onPaymentSuccess: noop,
    ),
    for (final tab in [0, 1, 2]) 'Bookings tab $tab': () => MyBookingsScreen(onBookNew: noop, initialTab: tab),
    'Credits': () => const CreditsScreen(),
    'Profile': () => ClientProfileScreen(
      onOpenSettings: noop,
      onOpenQr: noop,
      onOpenFavorites: noop,
      onOpenNotifications: noop,
      onOpenBookings: (_) {},
      onOpenCredits: noop,
      onOpenMap: noop,
    ),
    'Settings client': () =>
        SettingsScreen(onBack: noop, onLogout: noop, onOpenNotifications: noop, onOpenCredits: noop),
    'Settings master': () => SettingsScreen(isMaster: true, onBack: noop, onLogout: noop),
    'Notifications': () => NotificationsScreen(onBack: noop, onNotificationTap: (_) {}),
    'Favorites': () => FavoritesScreen(onBack: noop, onSalonTap: (_) {}, onMasterTap: (_) {}, onBookSalon: (_) {}),
    'Master dashboard': () => MasterDashboardScreen(onOpenSchedule: noop, onOpenEarnings: noop, onScanQr: noop),
    'Master schedule': () => MasterScheduleScreen(onBack: noop),
    'Master earnings': () => MasterEarningsScreen(onBack: noop),
    'Master account': () => MasterAccountScreen(
      onOpenSchedule: noop,
      onOpenEarnings: noop,
      onOpenScanner: noop,
      onOpenSettings: noop,
      onLogout: noop,
    ),
  };

  for (final size in const [Size(390, 844), Size(360, 690)]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} @ ${size.width.toInt()}', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: entry.value(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        // Ошибки вёрстки (overflow) фреймворк сам превращает в падение теста с подробностями
      });
    }
  }

  test('QR: валидный токен ближайшей записи принимается, чужой — нет', () {
    final state = AppStateService();
    final booking = state.activeBookings.firstWhere((b) => b.salonName == state.masterSalon);
    expect(state.validateVisitQr('garbage').isSuccess, isFalse);
    expect(state.validateVisitQr('GZL|nope|${DateTime.now().millisecondsSinceEpoch}').isSuccess, isFalse);
    final old = DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
    expect(state.validateVisitQr('GZL|${booking.id}|$old').error, contains('устарел'));
    expect(state.validateVisitQr(state.visitQrToken(booking), ignoreTimeWindow: true).isSuccess, isTrue);
    // Запись неизменяемая: старый объект не меняется, актуальный статус — в сторе
    expect(booking.status, BookingStatus.active);
    expect(state.bookingById(booking.id)!.status, BookingStatus.completed);
  });
}
