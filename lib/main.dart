import 'package:flutter/material.dart';
import 'core/services/app_state_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/navigation/floating_bottom_bar.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/onboarding_registration_screen.dart';
import 'features/client_home/client_home_screen.dart';
import 'features/salons_map/salons_map_screen.dart';
import 'features/salon_detail/salon_detail_screen.dart';
import 'features/salon_detail/master_profile_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/booking/payment_screen.dart';
import 'features/my_bookings/my_bookings_screen.dart';
import 'features/subscription_credits/credits_screen.dart';
import 'features/client_qr/client_qr_modal.dart';
import 'features/profile_settings/client_profile_screen.dart';
import 'features/profile_settings/settings_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/master_cabinet/dashboard/master_dashboard_screen.dart';
import 'features/master_cabinet/schedule/master_schedule_screen.dart';
import 'features/master_cabinet/qr_scanner/master_qr_scanner_screen.dart';
import 'features/master_cabinet/earnings/master_earnings_screen.dart';
import 'features/master_cabinet/profile/master_account_screen.dart';
import 'core/models/booking_draft.dart';
import 'core/utils/result.dart';
import 'core/services/masters_repository.dart';
import 'core/widgets/sheets/app_sheet.dart';

void main() {
  runApp(const GozallikApp());
}

class GozallikApp extends StatelessWidget {
  const GozallikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Go'zallik",
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      home: const RootNavigationContainer(),
    );
  }
}

class RootNavigationContainer extends StatefulWidget {
  const RootNavigationContainer({super.key});

  @override
  State<RootNavigationContainer> createState() => _RootNavigationContainerState();
}

class _RootNavigationContainerState extends State<RootNavigationContainer> {
  // Режим роли: false = Клиент, true = Мастер («Usta»)
  bool _isMasterMode = false;

  // Авторизован ли пользователь (по умолчанию false, чтобы сразу открылся экран логина)
  bool _isAuthenticated = false;

  // Режим первичной регистрации/онбординга (M-01, M-02)
  bool _isRegistering = false;

  // Табы навигации
  int _clientTabIndex = 0; // 0: Главная, 1: Поиск/Карта, 2: Записи, 3: Кредиты, 4: Профиль
  int _masterTabIndex = 0; // 0: Сегодня, 1: Время, 2: Сканер, 3: Доход, 4: Профиль

  // Стек внутренних переходов экранов: «Назад» возвращает туда, откуда пришли
  final List<String> _subStack = [];
  String get _activeSubScreen => _subStack.isEmpty ? '' : _subStack.last;

  void _push(String screen) => setState(() => _subStack.add(screen));
  void _pop() => setState(() {
    if (_subStack.isNotEmpty) _subStack.removeLast();
  });

  void _openSalon(String salonId) {
    _selectedSalonId = salonId;
    _push('salon_detail');
  }

  void _openMaster(String masterId) {
    _selectedMasterId = masterId;
    _push('master_profile');
  }

  void _goToClientTab(int index, {int bookingsTab = 0}) => setState(() {
    _subStack.clear();
    _clientTabIndex = index;
    _bookingsInitialTab = bookingsTab;
    if (index != 1) _mapFocusSalonId = null;
  });

  // Салоны и мастера в навигации — только по id
  String _selectedSalonId = '';
  String _selectedMasterId = '';

  // Параметры записи (M-08): откуда пришли — салон, мастер, услуга
  String? _bookingMasterId;
  MasterServiceItem? _bookingService;
  BookingDraft? _pendingDraft;

  // Салон, который нужно показать на карте («На карте» из карточки салона)
  String? _mapFocusSalonId;

  // Вкладка «Мои записи», которую открыть (0 — активные, 1 — прошедшие)
  int _bookingsInitialTab = 0;

  void _startBooking({required String salonId, String? masterId, MasterServiceItem? service}) {
    _selectedSalonId = salonId;
    _bookingMasterId = masterId;
    _bookingService = service;
    _push('booking');
  }

  void _showSalonOnMap(String salonId) {
    setState(() {
      _subStack.clear();
      _mapFocusSalonId = salonId;
      _clientTabIndex = 1;
    });
  }

  void _onBookingConfirmed(BookingDraft draft, String paymentMethod) {
    if (paymentMethod == PaymentMethods.online) {
      // До оплаты убеждаемся, что запись вообще возможна — чтобы не взять деньги за невозможную запись
      final check = AppStateService().validateNewBooking(
        salonId: draft.salonId,
        masterId: draft.masterId,
        serviceId: draft.serviceId,
        startsAt: draft.dateTime,
        durationMinutes: draft.durationMinutes,
        baseCredits: draft.baseCredits,
        paymentMethod: paymentMethod,
      );
      if (check case Failure(:final error)) {
        showAppSnack(context, error.message);
        return;
      }
      _pendingDraft = draft;
      _push('payment');
      return;
    }
    _finalizeBooking(draft, paymentMethod);
  }

  void _finalizeBooking(BookingDraft draft, String paymentMethod) {
    final result = AppStateService().createBooking(
      salonId: draft.salonId,
      salonName: draft.salonName,
      serviceId: draft.serviceId,
      serviceName: draft.serviceName,
      masterId: draft.masterId,
      masterName: draft.masterName,
      dateTime: draft.dateTime,
      durationMinutes: draft.durationMinutes,
      baseCredits: draft.baseCredits,
      sumPrice: draft.sumPrice,
      paymentMethod: paymentMethod,
    );

    switch (result) {
      case Failure(:final error):
        // Остаёмся на экране записи (с оплаты — возвращаемся на него) и объясняем причину
        if (_activeSubScreen == 'payment') _pop();
        showAppSnack(context, error.message);
      case Success():
        _pendingDraft = null;
        _goToClientTab(2); // Переходим сразу во вкладку «Мои записи»
        final message = switch (paymentMethod) {
          PaymentMethods.credits => 'Запись оформлена! Зарезервировано ${draft.credits} кр.',
          PaymentMethods.online => 'Оплата прошла, запись оформлена!',
          _ => 'Запись оформлена! Оплата при визите в салон.',
        };
        showAppSnack(context, message, success: true);
    }
  }

  /// Выход: состояние данных и навигации возвращается к начальному,
  /// чтобы следующий вход (в том числе другой ролью) не видел данные прошлого пользователя
  void _logout() {
    AppStateService().resetSession();
    setState(() {
      _isAuthenticated = false;
      _isMasterMode = false;
      _isRegistering = false;
      _subStack.clear();
      _clientTabIndex = 0;
      _masterTabIndex = 0;
      _selectedSalonId = '';
      _selectedMasterId = '';
      _bookingMasterId = null;
      _bookingService = null;
      _pendingDraft = null;
      _mapFocusSalonId = null;
      _bookingsInitialTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      if (_isRegistering) {
        return OnboardingRegistrationScreen(
          onCompleted: () {
            setState(() {
              _isRegistering = false;
              _isMasterMode = false;
              _isAuthenticated = true;
              _clientTabIndex = 0;
            });
          },
          onBackToLogin: () {
            setState(() => _isRegistering = false);
          },
        );
      }

      return AuthScreen(
        onLoginSuccess: (isMaster) {
          setState(() {
            _isMasterMode = isMaster;
            _isAuthenticated = true;
            _clientTabIndex = 0;
            _masterTabIndex = 0;
            _subStack.clear();
          });
        },
        onRegisterTap: () {
          setState(() => _isRegistering = true);
        },
      );
    }

    // Бар — штатный bottomNavigationBar: тело экрана заканчивается над ним,
    // контент не уходит под бар, а бар не перекрывает кнопки экранов.
    return PopScope(
      canPop: _subStack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pop();
      },
      child: Scaffold(
        backgroundColor: FloatingBottomBar.backgroundColor,
        body: _buildCurrentScreen(),
        // Бар отображается только в основных вкладках
        bottomNavigationBar: _activeSubScreen.isEmpty
            ? (_isMasterMode ? _buildMasterBottomBar() : _buildClientBottomBar())
            : null,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    // Внутренние подэкраны
    if (_activeSubScreen == 'salon_detail') {
      return SalonDetailScreen(
        key: ValueKey('salon_$_selectedSalonId'),
        salonId: _selectedSalonId,
        onBack: _pop,
        onBook: ({masterId, service}) => _startBooking(salonId: _selectedSalonId, masterId: masterId, service: service),
        onMasterTap: _openMaster,
        onShowOnMap: _showSalonOnMap,
      );
    }
    if (_activeSubScreen == 'master_profile') {
      return MasterProfileScreen(
        key: ValueKey('master_$_selectedMasterId'),
        masterId: _selectedMasterId,
        onBack: _pop,
        onBookMaster: (service) {
          final master = MastersRepository().getMasterById(_selectedMasterId);
          if (master == null) return;
          _startBooking(salonId: master.salonId, masterId: master.id, service: service);
        },
        onOpenSalon: _openSalon,
      );
    }
    if (_activeSubScreen == 'booking') {
      return BookingScreen(
        key: ValueKey('booking_${_selectedSalonId}_${_bookingMasterId}_${_bookingService?.id}'),
        salonId: _selectedSalonId,
        initialMasterId: _bookingMasterId,
        initialService: _bookingService,
        onBack: _pop,
        onConfirm: _onBookingConfirmed,
        onTopUpCredits: () => _goToClientTab(3),
      );
    }
    if (_activeSubScreen == 'payment' && _pendingDraft != null) {
      return PaymentScreen(
        draft: _pendingDraft!,
        onBack: _pop,
        onPaymentSuccess: () => _finalizeBooking(_pendingDraft!, PaymentMethods.online),
      );
    }
    if (_activeSubScreen == 'favorites') {
      return FavoritesScreen(
        onBack: _pop,
        onSalonTap: _openSalon,
        onMasterTap: _openMaster,
        onBookSalon: (salonId) => _startBooking(salonId: salonId),
      );
    }
    if (_activeSubScreen == 'notifications') {
      return NotificationsScreen(
        onBack: _pop,
        onNotificationTap: (notification) {
          switch (notification.type) {
            case AppNotificationType.reminder:
              _goToClientTab(2);
            case AppNotificationType.review:
              _goToClientTab(2, bookingsTab: 1);
            case AppNotificationType.credits:
              _goToClientTab(3);
            case AppNotificationType.promo:
              final salonId = notification.salonId;
              if (salonId != null) _openSalon(salonId);
          }
        },
      );
    }
    if (_activeSubScreen == 'settings') {
      return SettingsScreen(
        isMaster: _isMasterMode,
        onBack: _pop,
        onLogout: _logout,
        onOpenNotifications: _isMasterMode ? null : () => _push('notifications'),
        onOpenCredits: _isMasterMode ? null : () => _goToClientTab(3),
      );
    }

    // Основные экраны мастера
    if (_isMasterMode) {
      switch (_masterTabIndex) {
        case 0:
          return MasterDashboardScreen(
            onOpenSchedule: () => setState(() => _masterTabIndex = 1),
            onOpenEarnings: () => setState(() => _masterTabIndex = 3),
            onScanQr: () => setState(() => _masterTabIndex = 2),
          );
        case 1:
          return MasterScheduleScreen(onBack: () => setState(() => _masterTabIndex = 0));
        case 2:
          return MasterQrScannerScreen(onBack: () => setState(() => _masterTabIndex = 0));
        case 3:
          return MasterEarningsScreen(onBack: () => setState(() => _masterTabIndex = 0));
        case 4:
        default:
          return MasterAccountScreen(
            onOpenSchedule: () => setState(() => _masterTabIndex = 1),
            onOpenEarnings: () => setState(() => _masterTabIndex = 3),
            onOpenScanner: () => setState(() => _masterTabIndex = 2),
            onOpenSettings: () => _push('settings'),
            onLogout: _logout,
          );
      }
    }

    // Основные экраны клиента
    switch (_clientTabIndex) {
      case 0:
        return ClientHomeScreen(
          onOpenMap: () => _goToClientTab(1),
          onSalonTap: _openSalon,
          onMasterTap: _openMaster,
          onOpenFavorites: () => _push('favorites'),
          onOpenNotifications: () => _push('notifications'),
          onOpenCredits: () => _goToClientTab(3),
          onOpenProfile: () => _goToClientTab(4),
        );
      case 1:
        return SalonsMapScreen(
          key: ValueKey('map_$_mapFocusSalonId'),
          initialSalonId: _mapFocusSalonId,
          onBack: () => _goToClientTab(0),
          onSelectSalon: _openSalon,
        );
      case 2:
        return MyBookingsScreen(
          key: ValueKey('bookings_$_bookingsInitialTab'),
          initialTab: _bookingsInitialTab,
          onBookNew: () => _goToClientTab(0),
          onOpenSalon: _openSalon,
        );
      case 3:
        return const CreditsScreen();
      case 4:
      default:
        return ClientProfileScreen(
          onOpenSettings: () => _push('settings'),
          onOpenQr: () => ClientQrModal.showForNearestBooking(context, onBookNew: () => _goToClientTab(0)),
          onOpenFavorites: () => _push('favorites'),
          onOpenNotifications: () => _push('notifications'),
          onOpenBookings: (tab) => _goToClientTab(2, bookingsTab: tab),
          onOpenCredits: () => _goToClientTab(3),
          onOpenMap: () => _goToClientTab(1),
        );
    }
  }

  Widget _buildClientBottomBar() {
    return FloatingBottomBar(
      currentIndex: _clientTabIndex,
      onTap: (index) => _goToClientTab(index),
      items: const [
        FloatingBarItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Главная'),
        FloatingBarItem(icon: Icons.search, selectedIcon: Icons.search, label: 'Поиск'),
        FloatingBarItem(icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: 'Записи'),
        FloatingBarItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: 'Кредиты',
        ),
        FloatingBarItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Профиль'),
      ],
    );
  }

  Widget _buildMasterBottomBar() {
    return FloatingBottomBar(
      currentIndex: _masterTabIndex,
      onTap: (index) => setState(() => _masterTabIndex = index),
      items: const [
        FloatingBarItem(icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: 'Сегодня'),
        FloatingBarItem(icon: Icons.access_time_outlined, selectedIcon: Icons.access_time, label: 'Время'),
        FloatingBarItem(icon: Icons.qr_code_scanner, selectedIcon: Icons.qr_code_scanner, label: 'Сканер'),
        FloatingBarItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Доход'),
        FloatingBarItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Профиль'),
      ],
    );
  }
}
