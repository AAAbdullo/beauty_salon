import 'package:flutter/material.dart';
import 'core/services/app_state_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/navigation/floating_bottom_bar.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/onboarding_registration_screen.dart';
import 'features/client_home/client_home_screen.dart';
import 'features/salons_map/salons_map_screen.dart';
import 'features/salon_detail/salon_detail_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/booking/payment_screen.dart';
import 'features/my_bookings/my_bookings_screen.dart';
import 'features/subscription_credits/credits_screen.dart';
import 'features/client_qr/client_qr_modal.dart';
import 'features/profile_settings/client_profile_screen.dart';
import 'features/profile_settings/settings_screen.dart';
import 'features/master_cabinet/dashboard/master_dashboard_screen.dart';
import 'features/master_cabinet/schedule/master_schedule_screen.dart';
import 'features/master_cabinet/qr_scanner/master_qr_scanner_screen.dart';
import 'features/master_cabinet/earnings/master_earnings_screen.dart';

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

  // Стек внутренних переходов экранов
  String _activeSubScreen = '';
  String _selectedSalonName = 'Nur Beauty';

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
            _activeSubScreen = '';
          });
        },
        onRegisterTap: () {
          setState(() => _isRegistering = true);
        },
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildCurrentScreen(),
          // Нижний плавающий бар отображается только в основных вкладках
          if (_activeSubScreen.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _isMasterMode ? _buildMasterBottomBar() : _buildClientBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    // Внутренние подэкраны
    if (_activeSubScreen == 'salon_detail') {
      return SalonDetailScreen(
        salonName: _selectedSalonName,
        onBack: () => setState(() => _activeSubScreen = ''),
        onBookNow: () => setState(() => _activeSubScreen = 'booking'),
      );
    }
    if (_activeSubScreen == 'booking') {
      return BookingScreen(
        onBack: () => setState(() => _activeSubScreen = 'salon_detail'),
        onPaymentStep: () => setState(() => _activeSubScreen = 'payment'),
      );
    }
    if (_activeSubScreen == 'payment') {
      return PaymentScreen(
        onBack: () => setState(() => _activeSubScreen = 'booking'),
        onPaymentSuccess: () {
          AppStateService().createBooking(
            salonName: _selectedSalonName,
            serviceName: 'Маникюр классический',
            masterName: 'Алена',
            date: 'Сегодня',
            time: '16:30',
            credits: 34,
            sumPrice: 150000,
            paymentMethod: 'Кредиты',
          );
          setState(() {
            _activeSubScreen = '';
            _clientTabIndex = 2; // Переходим сразу во вкладку «Мои записи»
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Запись успешно оформлена! Списано 34 кр.'),
            ),
          );
        },
      );
    }
    if (_activeSubScreen == 'settings') {
      return SettingsScreen(
        onBack: () => setState(() => _activeSubScreen = ''),
        onLogout: () => setState(() {
          _isAuthenticated = false;
          _activeSubScreen = '';
        }),
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
          return MasterScheduleScreen(
            onBack: () => setState(() => _masterTabIndex = 0),
          );
        case 2:
          return MasterQrScannerScreen(
            onBack: () => setState(() => _masterTabIndex = 0),
          );
        case 3:
          return MasterEarningsScreen(
            onBack: () => setState(() => _masterTabIndex = 0),
          );
        case 4:
        default:
          return ClientProfileScreen(
            onOpenSettings: () => setState(() => _activeSubScreen = 'settings'),
            onOpenQr: () => setState(() => _masterTabIndex = 2),
          );
      }
    }

    // Основные экраны клиента
    switch (_clientTabIndex) {
      case 0:
        return ClientHomeScreen(
          onOpenMap: () => setState(() => _clientTabIndex = 1),
          onSalonTap: (name) => setState(() {
            _selectedSalonName = name;
            _activeSubScreen = 'salon_detail';
          }),
        );
      case 1:
        return SalonsMapScreen(
          onBack: () => setState(() => _clientTabIndex = 0),
          onSelectSalon: (name) => setState(() {
            _selectedSalonName = name;
            _activeSubScreen = 'salon_detail';
          }),
        );
      case 2:
        return MyBookingsScreen(
          onBookNew: () => setState(() => _clientTabIndex = 0),
        );
      case 3:
        return const CreditsScreen();
      case 4:
      default:
        return ClientProfileScreen(
          onOpenSettings: () => setState(() => _activeSubScreen = 'settings'),
          onOpenQr: () => ClientQrModal.show(context),
        );
    }
  }

  Widget _buildClientBottomBar() {
    return FloatingBottomBar(
      currentIndex: _clientTabIndex,
      onTap: (index) => setState(() => _clientTabIndex = index),
      items: const [
        FloatingBarItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Главная',
        ),
        FloatingBarItem(
          icon: Icons.search,
          selectedIcon: Icons.search,
          label: 'Поиск',
        ),
        FloatingBarItem(
          icon: Icons.calendar_today_outlined,
          selectedIcon: Icons.calendar_today,
          label: 'Записи',
        ),
        FloatingBarItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: 'Кредиты',
        ),
        FloatingBarItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Профиль',
        ),
      ],
    );
  }

  Widget _buildMasterBottomBar() {
    return FloatingBottomBar(
      currentIndex: _masterTabIndex,
      onTap: (index) => setState(() => _masterTabIndex = index),
      items: const [
        FloatingBarItem(
          icon: Icons.calendar_today_outlined,
          selectedIcon: Icons.calendar_today,
          label: 'Сегодня',
        ),
        FloatingBarItem(
          icon: Icons.access_time_outlined,
          selectedIcon: Icons.access_time,
          label: 'Время',
        ),
        FloatingBarItem(
          icon: Icons.qr_code_scanner,
          selectedIcon: Icons.qr_code_scanner,
          label: 'Сканер',
        ),
        FloatingBarItem(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Доход',
        ),
        FloatingBarItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Профиль',
        ),
      ],
    );
  }
}
