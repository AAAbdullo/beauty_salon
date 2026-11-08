import '../../models/booking_item.dart';
import '../../services/master_cabinet_store.dart';
import '../../utils/clock.dart';
import '../repositories/master_cabinet_repository.dart';
import 'mock_network.dart';

/// Мок кабинета мастера: «сервером» служит [MasterCabinetStore] (график) и `BookingStore` (брони, доход).
class MockMasterCabinetRepository implements MasterCabinetRepository {
  MockMasterCabinetRepository({MockNetwork? network, MasterCabinetStore? store})
    : _network = network ?? MockNetwork(),
      _store = store ?? MasterCabinetStore();

  final MockNetwork _network;
  final MasterCabinetStore _store;

  @override
  Future<MasterDashboardData> dashboard() => _network(
    () => MasterDashboardData(
      today: _store.getAppointments(tomorrow: false),
      tomorrow: _store.getAppointments(tomorrow: true),
      notifications: _store.notifications,
      visitsThisMonth: _store.visitsForMonth(0).length,
      monthClients: _store.clientsForMonth(0),
      revenueToday: _store.revenueForDay(AppClock.now()),
    ),
  );

  @override
  Future<MasterEarningsData> earnings(int monthOffset) => _network(
    () => MasterEarningsData(
      visits: _store.visitsForMonth(monthOffset),
      revenue: _store.revenueForMonth(monthOffset),
      previousRevenue: _store.revenueForMonth(monthOffset + 1),
      payouts: List.of(_store.payouts),
    ),
  );

  @override
  Future<MasterAccountStats> accountStats() => _network(
    () => MasterAccountStats(
      workingDays: _store.workingWeekdays.length,
      visitsThisMonth: _store.visitsForMonth(0).length,
      revenueThisMonth: _store.revenueForMonth(0),
    ),
  );

  @override
  Future<MasterWeek> week() => _network(
    () => MasterWeek(
      days: {for (var w = DateTime.monday; w <= DateTime.sunday; w++) w: _store.getDay(w)},
      canEdit: _store.salonAllowsScheduleEditing,
    ),
  );

  @override
  Future<MasterClientProfile?> clientProfile(String clientId) => _network(() {
    final bookings = _store.bookingsOfClient(clientId);
    if (bookings.isEmpty) return null;
    final now = AppClock.now();
    MasterClientBooking view(BookingItem b) => MasterClientBooking(
      bookingId: b.id,
      serviceName: b.serviceName,
      startsAt: b.startsAt,
      status: b.status,
      priceLabel: b.priceLabel,
    );
    final upcoming = bookings.where((b) => b.status == BookingStatus.active && b.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final history = bookings.where((b) => !upcoming.contains(b)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    // Имя и фото — из самой свежей записи (клиент мог их сменить)
    final latest = bookings.reduce((a, b) => a.startsAt.isAfter(b.startsAt) ? a : b);
    return MasterClientProfile(
      clientId: clientId,
      name: latest.clientName,
      avatar: latest.clientAvatar,
      upcoming: upcoming.map(view).toList(),
      history: history.map(view).toList(),
    );
  });

  @override
  Future<void> saveDay(int weekday, DaySchedule schedule) => _network(() => _store.saveDay(weekday, schedule));

  @override
  Future<void> copyDayTo(DaySchedule source, Iterable<int> weekdays) =>
      _network(() => _store.copyDayTo(source, weekdays));

  @override
  Future<void> setDayWorking(int weekday, bool isWorking) =>
      _network(() => _store.setDayWorking(weekday, isWorking));
}
