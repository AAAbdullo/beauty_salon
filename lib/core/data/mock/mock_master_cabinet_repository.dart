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
  Future<void> saveDay(int weekday, DaySchedule schedule) => _network(() => _store.saveDay(weekday, schedule));

  @override
  Future<void> copyDayTo(DaySchedule source, Iterable<int> weekdays) =>
      _network(() => _store.copyDayTo(source, weekdays));

  @override
  Future<void> setDayWorking(int weekday, bool isWorking) =>
      _network(() => _store.setDayWorking(weekday, isWorking));
}
