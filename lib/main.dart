import 'package:flutter/material.dart';
import 'core/services/app_state_service.dart';
import 'core/theme/app_appearance.dart';
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
import 'dart:async';
import 'core/data/app_dependencies.dart';
import 'core/data/app_scope.dart';
import 'core/data/repositories/auth_repository.dart';
import 'core/data/repositories/bookings_repository.dart';
import 'core/data/repositories/payments_repository.dart';
import 'core/data/repository_exception.dart';
import 'core/models/booking_draft.dart';
import 'core/utils/result.dart';
import 'core/services/masters_repository.dart';
import 'core/widgets/sheets/app_sheet.dart';

void main() {
  runApp(const GozallikApp());
}

class GozallikApp extends StatefulWidget {
  /// Зависимости приложения; по умолчанию — мок-реализации. В тестах подставляются свои.
  final AppDependencies? dependencies;

  /// Тема вместо стандартной — для тестов (стандартная тянет шрифты Google по сети)
  @visibleForTesting
  final ThemeData? themeOverride;

  const GozallikApp({super.key, this.dependencies, this.themeOverride});

  @override
  State<GozallikApp> createState() => _GozallikAppState();
}

class _GozallikAppState extends State<GozallikApp> with WidgetsBindingObserver {
  // Создаются один раз: пересборка виджета не должна сбрасывать удержания слотов и сессию
  late final AppDependencies _dependencies = widget.dependencies ?? AppDependencies.mock();

  final _appearance = AppAppearance.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appearance.addListener(_onAppearanceChanged);
    AppAppearance.applyPalette(_appearance.resolveDark(WidgetsBinding.instance.platformDispatcher.platformBrightness));
  }

  @override
  void dispose() {
    _appearance.removeListener(_onAppearanceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _onAppearanceChanged();

  void _onAppearanceChanged() {
    final dark = _appearance.resolveDark(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    if (!AppAppearance.applyPalette(dark) || !mounted) return;
    setState(() {});
    AppAppearance.rebuildAll();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: _dependencies,
      child: MaterialApp(
        title: "Go'zallik",
        debugShowCheckedModeBanner: false,
        theme: widget.themeOverride ?? lightTheme,
        darkTheme: widget.themeOverride == null ? darkTheme : null,
        themeMode: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
        themeAnimationDuration: Duration.zero, // палитра переключается мгновенно и целиком
        home: const RootNavigationContainer(),
      ),
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

  // Идёт восстановление сессии из сохранённого токена
  bool _isRestoringSession = true;

  AppDependencies get _deps => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  /// При запуске: если токен сохранён и не истёк, сразу входим (роль — из токена)
  Future<void> _restoreSession() async {
    AuthSession? session;
    try {
      session = await _deps.auth.restoreSession();
    } on RepositoryException {
      session = null; // без сети просто покажем экран входа
    }
    if (!mounted) return;
    setState(() {
      _isRestoringSession = false;
      if (session != null) {
        _isMasterMode = session.isMaster;
        _isAuthenticated = true;
      }
    });
  }

  // Режим первичной регистрации/онбординга (M-01, M-02)
  bool _isRegistering = false;

  // --- Навигация ---------------------------------------------------------------------------
  //
  // Вкладки создаются при первом открытии и дальше остаются живыми (IndexedStack): фильтры главной,
  // карта с маршрутом и несохранённый график мастера не теряются при переключении.
  // Внутренние страницы лежат стеком; каждая хранит свои параметры (салон, мастер, услугу, черновик),
  // а нижние страницы остаются живыми под верхней — «Назад» с оплаты возвращает на экран записи
  // с выбранным временем, а «Назад» из мастера — на салон, откуда пришли.

  int _clientTabIndex = 0; // 0: Главная, 1: Поиск/Карта, 2: Записи, 3: Кредиты, 4: Профиль
  int _masterTabIndex = 0; // 0: Сегодня, 1: Время, 2: Сканер, 3: Доход, 4: Профиль

  // Вкладки, которые уже открывали (только они построены)
  final Set<int> _clientTabsBuilt = {0};
  final Set<int> _masterTabsBuilt = {0};

  final List<_Page> _pages = [];

  // Идёт оплата: «Назад» (системная и на экране) в это время не должна закрывать экран оплаты
  bool _paymentBusy = false;

  // Идёт создание записи (защита от повторного запуска)
  bool _finalizing = false;

  // Завершится, когда закончится оплата (успех / назад / отказ): экран записи ждёт этого результата
  Completer<bool>? _paymentFlow;

  // «На карте» из карточки салона: номер запроса меняет ключ карты и заново наводит камеру
  String? _mapFocusSalonId;
  int _mapFocusNonce = 0;

  // Вкладка «Мои записи», которую открыть (0 — активные, 1 — прошедшие)
  int _bookingsInitialTab = 0;

  bool get _atRoot => _pages.isEmpty && (_isMasterMode ? _masterTabIndex == 0 : _clientTabIndex == 0);

  void _push(_Page page) => setState(() => _pages.add(page));

  /// Закрыть верхнюю страницу. С экрана оплаты во время платежа уйти нельзя.
  void _pop() {
    if (_pages.isEmpty) return;
    final top = _pages.last;
    if (top.kind == _PageKind.payment) {
      if (_paymentBusy) {
        showAppSnack(context, 'Идёт оплата. Подождите, пока она завершится.');
        return;
      }
      _finishPaymentFlow(false);
    }
    setState(() => _pages.removeLast());
  }

  /// Системная «Назад»: сначала страницы, затем возврат на первую вкладку, и только оттуда — выход
  void _handleBack() {
    if (_pages.isNotEmpty) {
      _pop();
    } else if (_isMasterMode) {
      setState(() => _masterTabIndex = 0);
    } else {
      _goToClientTab(0);
    }
  }

  void _finishPaymentFlow(bool success) {
    final flow = _paymentFlow;
    _paymentFlow = null;
    if (flow != null && !flow.isCompleted) flow.complete(success);
  }

  /// Убрать все внутренние страницы (переход на вкладку, выход)
  void _clearPages() {
    _finishPaymentFlow(false);
    _paymentBusy = false;
    _pages.clear();
  }

  void _openSalon(String salonId) => _push(_Page(_PageKind.salon, salonId: salonId));

  void _openMaster(String masterId) => _push(_Page(_PageKind.master, masterId: masterId));

  void _goToClientTab(int index, {int? bookingsTab}) => setState(() {
    _clearPages();
    _clientTabIndex = index;
    _clientTabsBuilt.add(index);
    if (bookingsTab != null) _bookingsInitialTab = bookingsTab;
  });

  void _goToMasterTab(int index) => setState(() {
    _masterTabIndex = index;
    _masterTabsBuilt.add(index);
  });

  void _startBooking({required String salonId, String? masterId, MasterServiceItem? service}) =>
      _push(_Page(_PageKind.booking, salonId: salonId, masterId: masterId, service: service));

  void _showSalonOnMap(String salonId) {
    setState(() {
      _clearPages();
      _mapFocusSalonId = salonId;
      _mapFocusNonce++;
      _clientTabIndex = 1;
      _clientTabsBuilt.add(1);
    });
  }

  /// Клиент подтвердил запись на экране записи. `true` — запись оформлена, `false` — отказ или оплата
  /// отменена (причина показана); экран записи при этом остаётся открытым с выбранным временем.
  Future<bool> _onBookingConfirmed(BookingDraft draft, String paymentMethod) async {
    if (paymentMethod == PaymentMethods.online) {
      // До оплаты убеждаемся, что запись вообще возможна — чтобы не взять деньги за невозможную запись
      try {
        final check = await _deps.bookings.validate(
          salonId: draft.salonId,
          masterId: draft.masterId,
          serviceId: draft.serviceId,
          startsAt: draft.dateTime,
          durationMinutes: draft.durationMinutes,
          baseCredits: draft.baseCredits,
          paymentMethod: paymentMethod,
        );
        if (!mounted) return false;
        if (check case Failure(:final error)) {
          showAppSnack(context, error.message);
          return false;
        }
      } on RepositoryException catch (e) {
        if (mounted) showAppSnack(context, e.message);
        return false;
      }
      // Экран записи остаётся под оплатой и сохраняет удержание слота; результат придёт, когда оплата закончится
      final flow = Completer<bool>();
      _paymentFlow = flow;
      _push(_Page(_PageKind.payment, draft: draft));
      return flow.future;
    }
    return _finalizeBooking(draft, paymentMethod);
  }

  /// Создание записи по удержанию слота. [receipt] — квитанция онлайн-оплаты, если платили заранее.
  /// Если запись создать не удалось после оплаты, платёж возвращается.
  Future<bool> _finalizeBooking(BookingDraft draft, String paymentMethod, {PaymentReceipt? receipt}) async {
    if (_finalizing) return false;
    _finalizing = true;
    try {
      final result = await _deps.bookings.create(
        CreateBookingRequest(
          idempotencyKey: draft.idempotencyKey,
          holdId: draft.holdId,
          salonId: draft.salonId,
          salonName: draft.salonName,
          serviceId: draft.serviceId,
          serviceName: draft.serviceName,
          masterId: draft.masterId,
          masterName: draft.masterName,
          startsAt: draft.dateTime,
          durationMinutes: draft.durationMinutes,
          baseCredits: draft.baseCredits,
          sumPrice: draft.sumPrice,
          paymentMethod: paymentMethod,
          paymentReceiptId: receipt?.id,
        ),
      );
      if (!mounted) return false;

      switch (result) {
        case Failure(:final error):
          var message = error.message;
          if (receipt != null) {
            // Деньги уже списаны, а записи нет — возвращаем платёж
            unawaited(_deps.payments.refund(receiptId: receipt.id, idempotencyKey: 'refund-${draft.idempotencyKey}'));
            message = '$message Платёж будет возвращён.';
          }
          // С экрана оплаты возвращаемся на экран записи, он ждёт результата
          if (_pages.isNotEmpty && _pages.last.kind == _PageKind.payment) {
            _paymentBusy = false;
            _finishPaymentFlow(false);
            setState(() => _pages.removeLast());
          }
          showAppSnack(context, message);
          return false;
        case Success():
          _finishPaymentFlow(true);
          _goToClientTab(2); // Переходим сразу во вкладку «Мои записи»
          final message = switch (paymentMethod) {
            PaymentMethods.credits => 'Запись оформлена! Зарезервировано ${draft.credits} кр.',
            PaymentMethods.online => 'Оплата прошла, запись оформлена!',
            _ => 'Запись оформлена! Оплата при визите в салон.',
          };
          showAppSnack(context, message, success: true);
          return true;
      }
    } on RepositoryException catch (e) {
      // Связь оборвалась: ключ идемпотентности сохранён, повторная попытка не создаст дубль
      if (mounted) showAppSnack(context, e.message);
      return false;
    } finally {
      _finalizing = false;
    }
  }

  /// Выход: состояние данных и навигации возвращается к начальному,
  /// чтобы следующий вход (в том числе другой ролью) не видел данные прошлого пользователя
  void _logout() {
    unawaited(_deps.auth.logout());
    AppStateService().resetSession();
    setState(() {
      _clearPages(); // экраны записи при этом освобождают удержания слотов
      _isAuthenticated = false;
      _isMasterMode = false;
      _isRegistering = false;
      _clientTabIndex = 0;
      _masterTabIndex = 0;
      _clientTabsBuilt
        ..clear()
        ..add(0);
      _masterTabsBuilt
        ..clear()
        ..add(0);
      _mapFocusSalonId = null;
      _bookingsInitialTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (!_isAuthenticated) {
      if (_isRegistering) {
        return OnboardingRegistrationScreen(
          onCompleted: () async {
            try {
              final session = await _deps.auth.completeRegistration(phone: AppStateService().clientPhone);
              if (!mounted) return;
              setState(() {
                _isRegistering = false;
                _isMasterMode = session.isMaster;
                _isAuthenticated = true;
                _clientTabIndex = 0;
              });
            } on RepositoryException catch (e) {
              if (mounted) showAppSnack(this.context, e.message);
            }
          },
          onBackToLogin: () {
            setState(() => _isRegistering = false);
          },
        );
      }

      return AuthScreen(
        onLoginSuccess: (session) {
          setState(() {
            // Роль берётся из токена сессии, а не из формы входа
            _isMasterMode = session.isMaster;
            _isAuthenticated = true;
            _clientTabIndex = 0;
            _masterTabIndex = 0;
            _clearPages();
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
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: FloatingBottomBar.backgroundColor,
        body: _buildBody(),
        // Бар отображается только в основных вкладках
        bottomNavigationBar: _pages.isEmpty
            ? (_isMasterMode ? _buildMasterBottomBar() : _buildClientBottomBar())
            : null,
      ),
    );
  }

  /// Вкладки и стек страниц. Нижние слои остаются в дереве (Offstage) и сохраняют своё состояние,
  /// но не рисуются и не получают нажатий; тикеры анимаций скрытых слоёв остановлены.
  Widget _buildBody() {
    final hasPages = _pages.isNotEmpty;
    return Stack(
      children: [
        Offstage(
          offstage: hasPages,
          child: TickerMode(enabled: !hasPages, child: _isMasterMode ? _buildMasterTabs() : _buildClientTabs()),
        ),
        for (var i = 0; i < _pages.length; i++)
          Offstage(
            offstage: i != _pages.length - 1,
            child: TickerMode(
              enabled: i == _pages.length - 1,
              child: KeyedSubtree(key: _pages[i].key, child: _buildPage(_pages[i])),
            ),
          ),
      ],
    );
  }

  Widget _buildPage(_Page page) {
    switch (page.kind) {
      case _PageKind.salon:
        return SalonDetailScreen(
          salonId: page.salonId!,
          onBack: _pop,
          onBook: ({masterId, service}) => _startBooking(salonId: page.salonId!, masterId: masterId, service: service),
          onMasterTap: _openMaster,
          onShowOnMap: _showSalonOnMap,
        );
      case _PageKind.master:
        return MasterProfileScreen(
          masterId: page.masterId!,
          onBack: _pop,
          onBookMaster: (master, service) =>
              _startBooking(salonId: master.salonId, masterId: master.id, service: service),
          onOpenSalon: _openSalon,
        );
      case _PageKind.booking:
        return BookingScreen(
          salonId: page.salonId!,
          initialMasterId: page.masterId,
          initialService: page.service,
          onBack: _pop,
          onConfirm: _onBookingConfirmed,
          onTopUpCredits: () => _goToClientTab(3),
        );
      case _PageKind.payment:
        final draft = page.draft!;
        return PaymentScreen(
          draft: draft,
          onBack: _pop,
          onBusyChanged: (busy) => _paymentBusy = busy,
          onPaid: (receipt) => _finalizeBooking(draft, PaymentMethods.online, receipt: receipt),
        );
      case _PageKind.favorites:
        return FavoritesScreen(
          onBack: _pop,
          onSalonTap: _openSalon,
          onMasterTap: _openMaster,
          onBookSalon: (salonId) => _startBooking(salonId: salonId),
        );
      case _PageKind.notifications:
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
      case _PageKind.settings:
        return SettingsScreen(
          isMaster: _isMasterMode,
          onBack: _pop,
          onLogout: _logout,
          onOpenNotifications: _isMasterMode ? null : () => _push(_Page(_PageKind.notifications)),
          onOpenCredits: _isMasterMode ? null : () => _goToClientTab(3),
        );
    }
  }

  /// Построенные вкладки живут в IndexedStack; ещё не открытые — пустые заглушки (не грузят данные заранее)
  Widget _tabStack(int index, Set<int> built, List<Widget Function()> tabs) {
    return IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < tabs.length; i++)
          TickerMode(enabled: i == index, child: built.contains(i) ? tabs[i]() : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildClientTabs() {
    return _tabStack(_clientTabIndex, _clientTabsBuilt, [
      () => ClientHomeScreen(
        onOpenMap: () => _goToClientTab(1),
        onSalonTap: _openSalon,
        onMasterTap: _openMaster,
        onOpenFavorites: () => _push(_Page(_PageKind.favorites)),
        onOpenNotifications: () => _push(_Page(_PageKind.notifications)),
        onOpenCredits: () => _goToClientTab(3),
        onOpenProfile: () => _goToClientTab(4),
      ),
      () => SalonsMapScreen(
        key: ValueKey('map_$_mapFocusNonce'),
        initialSalonId: _mapFocusSalonId,
        onBack: () => _goToClientTab(0),
        onSelectSalon: _openSalon,
      ),
      () => MyBookingsScreen(
        key: ValueKey('bookings_$_bookingsInitialTab'),
        initialTab: _bookingsInitialTab,
        onBookNew: () => _goToClientTab(0),
        onOpenSalon: _openSalon,
      ),
      () => const CreditsScreen(),
      () => ClientProfileScreen(
        onOpenSettings: () => _push(_Page(_PageKind.settings)),
        onOpenQr: () => ClientQrModal.showForNearestBooking(context, onBookNew: () => _goToClientTab(0)),
        onOpenFavorites: () => _push(_Page(_PageKind.favorites)),
        onOpenNotifications: () => _push(_Page(_PageKind.notifications)),
        onOpenBookings: (tab) => _goToClientTab(2, bookingsTab: tab),
        onOpenCredits: () => _goToClientTab(3),
        onOpenMap: () => _goToClientTab(1),
      ),
    ]);
  }

  Widget _buildMasterTabs() {
    return _tabStack(_masterTabIndex, _masterTabsBuilt, [
      () => MasterDashboardScreen(
        onOpenSchedule: () => _goToMasterTab(1),
        onOpenEarnings: () => _goToMasterTab(3),
        onScanQr: () => _goToMasterTab(2),
      ),
      // График остаётся живым: несохранённые правки не пропадают при переключении вкладок
      () => MasterScheduleScreen(onBack: () => _goToMasterTab(0)),
      // Камера не должна работать в скрытой вкладке — сканер строится только пока открыт
      () => _masterTabIndex == 2
          ? MasterQrScannerScreen(onBack: () => _goToMasterTab(0))
          : const SizedBox.shrink(),
      () => MasterEarningsScreen(onBack: () => _goToMasterTab(0)),
      () => MasterAccountScreen(
        onOpenSchedule: () => _goToMasterTab(1),
        onOpenEarnings: () => _goToMasterTab(3),
        onOpenScanner: () => _goToMasterTab(2),
        onOpenSettings: () => _push(_Page(_PageKind.settings)),
        onLogout: _logout,
      ),
    ]);
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
      onTap: _goToMasterTab,
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

enum _PageKind { salon, master, booking, payment, favorites, notifications, settings }

/// Страница внутреннего стека со своими параметрами. Ключ уникален: состояние страницы живёт, пока она в стеке.
class _Page {
  _Page(this.kind, {this.salonId, this.masterId, this.service, this.draft}) : key = UniqueKey();

  final _PageKind kind;
  final String? salonId;
  final String? masterId;
  final MasterServiceItem? service;
  final BookingDraft? draft;
  final Key key;
}
