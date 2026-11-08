import '../../models/booking_item.dart';
import '../../services/master_cabinet_store.dart';

/// Данные главного экрана мастера одним ответом
class MasterDashboardData {
  final List<MasterAppointment> today;
  final List<MasterAppointment> tomorrow;
  final List<MasterNotification> notifications;

  /// Выполненных визитов за текущий месяц
  final int visitsThisMonth;

  /// Клиенты текущего месяца (с подтверждёнными визитами)
  final List<MasterMonthClient> monthClients;
  final int revenueToday;

  const MasterDashboardData({
    required this.today,
    required this.tomorrow,
    required this.notifications,
    required this.visitsThisMonth,
    required this.monthClients,
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

/// Одна запись клиента к этому мастеру (для профиля клиента)
class MasterClientBooking {
  final String bookingId;
  final String serviceName;
  final DateTime startsAt;
  final BookingStatus status;
  final String priceLabel;

  const MasterClientBooking({
    required this.bookingId,
    required this.serviceName,
    required this.startsAt,
    required this.status,
    required this.priceLabel,
  });
}

/// Профиль клиента глазами мастера: кто это и как он ходит к этому мастеру
class MasterClientProfile {
  final String clientId;
  final String name;

  /// Фото клиента (ресурс приложения или файл); `null` — показывается значок
  final String? avatar;

  /// Предстоящие записи к этому мастеру (по возрастанию времени)
  final List<MasterClientBooking> upcoming;

  /// Прошедшие и отменённые записи (свежие сверху)
  final List<MasterClientBooking> history;

  const MasterClientProfile({
    required this.clientId,
    required this.name,
    required this.avatar,
    required this.upcoming,
    required this.history,
  });

  int get completedVisits => history.where((b) => b.status == BookingStatus.completed).length;
  int get cancelledCount => history.where((b) => b.status == BookingStatus.cancelled).length;
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

  /// Профиль клиента с его записями к этому мастеру; `null`, если такого клиента у мастера нет
  /// [BACKEND NOTE]: GET /api/v1/masters/me/clients/:id
  Future<MasterClientProfile?> clientProfile(String clientId);

  Future<void> saveDay(int weekday, DaySchedule schedule);

  /// Скопировать расписание на другие дни недели
  Future<void> copyDayTo(DaySchedule source, Iterable<int> weekdays);

  /// Сменить только признак «рабочий день»
  Future<void> setDayWorking(int weekday, bool isWorking);
}
