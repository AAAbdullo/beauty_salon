import '../services/app_state_service.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_bookings_repository.dart';
import 'mock/mock_catalog_repository.dart';
import 'mock/mock_master_cabinet_repository.dart';
import 'mock/mock_network.dart';
import 'mock/mock_payments_repository.dart';
import 'mock/mock_slots_repository.dart';
import 'mock/mock_subscription_repository.dart';
import 'mock/mock_visit_qr_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/bookings_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/master_cabinet_repository.dart';
import 'repositories/payments_repository.dart';
import 'repositories/slots_repository.dart';
import 'repositories/subscription_repository.dart';
import 'repositories/visit_qr_repository.dart';

/// Все источники данных приложения. Экраны получают их через `AppScope`, а не через синглтоны:
/// в тестах подставляются другие реализации, а при подключении бэкенда мок-реализации
/// заменяются на Dio-реализации в одном месте.
class AppDependencies {
  final AuthRepository auth;
  final CatalogRepository catalog;
  final SlotsRepository slots;
  final BookingsRepository bookings;
  final PaymentsRepository payments;
  final SubscriptionRepository subscription;
  final VisitQrRepository visitQr;
  final MasterCabinetRepository masterCabinet;

  /// Локальный реактивный кэш данных пользователя (профиль, абонемент, избранное, записи).
  /// Экраны читают его только отсюда. С бэкендом его заполняют репозитории, а не мок-синглтон.
  final AppStateService appState;

  const AppDependencies({
    required this.auth,
    required this.catalog,
    required this.slots,
    required this.bookings,
    required this.payments,
    required this.subscription,
    required this.visitQr,
    required this.masterCabinet,
    required this.appState,
  });

  /// Мок-реализации. [network] управляет задержкой и сбоями (в тестах — без задержки).
  factory AppDependencies.mock({MockNetwork? network, TokenStorage? tokenStorage}) {
    final net = network ?? MockNetwork(latency: const Duration(milliseconds: 150));
    final slots = MockSlotsRepository(network: net);
    return AppDependencies(
      auth: MockAuthRepository(storage: tokenStorage, network: net),
      catalog: MockCatalogRepository(network: net),
      slots: slots,
      bookings: MockBookingsRepository(slots: slots, network: net),
      payments: MockPaymentsRepository(slots: slots, network: net),
      subscription: MockSubscriptionRepository(network: net),
      visitQr: MockVisitQrRepository(network: net),
      masterCabinet: MockMasterCabinetRepository(network: net),
      appState: AppStateService(),
    );
  }
}
