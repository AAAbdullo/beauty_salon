import '../../services/master_cabinet_store.dart';

/// Данные главного экрана мастера одним ответом
class MasterDashboardData {
  final List<MasterAppointment> today;
  final List<MasterAppointment> tomorrow;
  final List<MasterNotification> notifications;

  /// Выполненных визитов за текущий месяц
  final int visitsThisMonth;
  final int revenueToday;

  const MasterDashboardData({
    required this.today,
    required this.tomorrow,
    required this.notifications,
    required this.visitsThisMonth,
    required this.revenueToday,
  });
}

/// Доход за выбранный месяц
class MasterEarningsData {
  final List<MasterVisitIncome> visits;
  final int revenue;
  final int previousRevenue;
  final List<MasterPayout> payouts;

  const MasterEarningsData({
    required this.visits,
    required this.revenue,
    required this.previousRevenue,
    required this.payouts,
  });
}

/// Цифры для кабинета мастера
class MasterAccountStats {
  final int workingDays;
  final int visitsThisMonth;
  final int revenueThisMonth;

  const MasterAccountStats({
    required this.workingDays,
    required this.visitsThisMonth,
    required this.revenueThisMonth,
  });
}

/// Недельный график и право его менять
class MasterWeek {
  /// День недели (1 = понедельник) → расписание
  final Map<int, DaySchedule> days;

  /// ТЗ, раздел 6: мастер меняет график, только если салон разрешил
  final bool canEdit;

  const MasterWeek({required this.days, required this.canEdit});

  Set<int> get workingWeekdays => days.entries.where((e) => e.value.isWorking).map((e) => e.key).toSet();
}

/// Кабинет мастера (раздел «Usta» в ТЗ). Брони, визиты и доход — проекции единого хранилища записей.
/// Все методы асинхронные: с бэкендом это сетевые запросы, экраны проходят состояния loading / error.
/// [BACKEND NOTE]:
///   GET  /api/v1/masters/me/schedule           — недельный график
///   PUT  /api/v1/masters/me/schedule/:weekday  — сохранить день
///   GET  /api/v1/masters/me/appointments?date= — брони на дату
///   GET  /api/v1/masters/me/notifications      — новые брони / отмены
///   GET  /api/v1/masters/me/earnings?month=    — визиты и выплаты
abstract interface class MasterCabinetRepository {
  Future<MasterDashboardData> dashboard();

  /// [monthOffset]: 0 — текущий месяц, 1 — предыдущий
  Future<MasterEarningsData> earnings(int monthOffset);

  Future<MasterAccountStats> accountStats();

  Future<MasterWeek> week();

  Future<void> saveDay(int weekday, DaySchedule schedule);

  /// Скопировать расписание на другие дни недели
  Future<void> copyDayTo(DaySchedule source, Iterable<int> weekdays);

  /// Сменить только признак «рабочий день»
  Future<void> setDayWorking(int weekday, bool isWorking);
}
