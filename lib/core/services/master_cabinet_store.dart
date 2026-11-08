/// Репозиторий кабинета мастера (раздел «Usta» в ТЗ).
///
/// График (рабочие часы, перерывы, слоты) хранится здесь. Брони, визиты и доход — НЕ хранятся:
/// это проекции единого `BookingStore`, поэтому запись клиента сразу видна мастеру,
/// а подтверждённый по QR визит сразу попадает в доход.
///
/// Время хранится в минутах от начала суток (540 = 09:00).
/// [BACKEND NOTE]: При подключении NestJS:
///   GET  /api/v1/masters/me/schedule           — недельный график
///   PUT  /api/v1/masters/me/schedule/:weekday  — сохранить день
///   GET  /api/v1/masters/me/appointments?date= — брони на дату
///   GET  /api/v1/masters/me/notifications      — новые брони / отмены
library;

import '../utils/clock.dart';
import 'app_state_service.dart';
import 'booking_store.dart';

String formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class TimeRange {
  final int start;
  final int end;

  const TimeRange(this.start, this.end);

  bool overlaps(TimeRange other) => start < other.end && other.start < end;

  String get label => '${formatMinutes(start)} – ${formatMinutes(end)}';

  TimeRange copyWith({int? start, int? end}) => TimeRange(start ?? this.start, end ?? this.end);
}

class ScheduleSlot {
  final TimeRange range;

  /// Открыт ли слот для записи вообще.
  /// Какие слоты доступны за кредиты — решает салон (K-02 / S-07), не мастер.
  final bool enabled;

  /// Слот добавлен вручную («Добавить произвольный слот»), а не сгенерирован из рабочего времени.
  final bool isCustom;

  const ScheduleSlot({required this.range, this.enabled = true, this.isCustom = false});

  ScheduleSlot copyWith({TimeRange? range, bool? enabled, bool? isCustom}) =>
      ScheduleSlot(range: range ?? this.range, enabled: enabled ?? this.enabled, isCustom: isCustom ?? this.isCustom);
}

class DaySchedule {
  final bool isWorking;
  final TimeRange workHours;
  final List<TimeRange> breaks;
  final List<ScheduleSlot> slots;

  const DaySchedule({required this.isWorking, required this.workHours, required this.breaks, required this.slots});

  DaySchedule copyWith({bool? isWorking, TimeRange? workHours, List<TimeRange>? breaks, List<ScheduleSlot>? slots}) =>
      DaySchedule(
        isWorking: isWorking ?? this.isWorking,
        workHours: workHours ?? this.workHours,
        breaks: breaks ?? List.of(this.breaks),
        slots: slots ?? List.of(this.slots),
      );

  bool isInBreak(TimeRange range) => breaks.any((b) => b.overlaps(range));

  /// Пересобирает часовые слоты по рабочему времени, сохраняя ручные слоты
  /// и состояние переключателей уже существующих слотов.
  DaySchedule regenerateSlots() {
    final previous = {for (final s in slots) s.range.start: s};
    final generated = <ScheduleSlot>[];
    for (var t = workHours.start; t + 60 <= workHours.end; t += 60) {
      final range = TimeRange(t, t + 60);
      final old = previous[t];
      generated.add(ScheduleSlot(range: range, enabled: old?.enabled ?? true));
    }
    // Ручной слот остаётся, только если он целиком в рабочем времени и не пересекается
    // со сгенерированными (иначе клиент увидел бы два наложенных слота).
    final custom = slots.where(
      (s) =>
          s.isCustom &&
          s.range.start >= workHours.start &&
          s.range.end <= workHours.end &&
          !generated.any((g) => g.range.overlaps(s.range)),
    );
    final all = [...generated, ...custom]..sort((a, b) => a.range.start.compareTo(b.range.start));
    return copyWith(slots: all);
  }

  /// Сколько слотов реально доступно клиентам.
  int get openSlotsCount => isWorking ? slots.where((s) => s.enabled && !isInBreak(s.range)).length : 0;
}

class MasterTemplate {
  final String title;
  final String subtitle;
  final TimeRange workHours;
  final List<TimeRange> breaks;

  const MasterTemplate(this.title, this.subtitle, this.workHours, this.breaks);
}

/// Запись глазами мастера — проекция [BookingItem], а не отдельные данные.
class MasterAppointment {
  final String bookingId;
  final String clientName;
  final String serviceName;
  final TimeRange time;
  final BookingStatus bookingStatus;
  final String? clientAvatar;

  const MasterAppointment({
    required this.bookingId,
    required this.clientName,
    required this.serviceName,
    required this.time,
    required this.bookingStatus,
    this.clientAvatar,
  });

  factory MasterAppointment.fromBooking(BookingItem b) {
    final start = b.startsAt.hour * 60 + b.startsAt.minute;
    return MasterAppointment(
      bookingId: b.id,
      clientName: b.clientName,
      serviceName: b.serviceName,
      time: TimeRange(start, start + b.durationMinutes),
      bookingStatus: b.status,
      clientAvatar: b.clientAvatar,
    );
  }

  bool get isActive => bookingStatus == BookingStatus.active;
  bool get isCancelled => bookingStatus == BookingStatus.cancelled;
  bool get isCompleted => bookingStatus == BookingStatus.completed;

  /// Подпись статуса для списка
  String get status => switch (bookingStatus) {
    BookingStatus.active => 'Подтверждено',
    BookingStatus.completed => 'Выполнено',
    BookingStatus.cancelled => 'Отменено',
  };
}

class MasterNotification {
  final String title;
  final String body;
  final String timeAgo;
  final bool isCancellation;

  const MasterNotification({
    required this.title,
    required this.body,
    required this.timeAgo,
    this.isCancellation = false,
  });
}

class MasterCabinetStore {
  static final MasterCabinetStore _instance = MasterCabinetStore._internal();
  factory MasterCabinetStore() => _instance;
  MasterCabinetStore._internal() {
    _seedWeek();
  }

  void _seedWeek() {
    _week.clear();
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final isWeekend = weekday == DateTime.sunday;
      _week[weekday] = DaySchedule(
        isWorking: !isWeekend,
        workHours: const TimeRange(540, 1140), // 09:00 – 19:00
        breaks: const [TimeRange(780, 840)], // 13:00 – 14:00
        slots: const [],
      ).regenerateSlots();
    }
  }

  /// Вернуть начальные данные (выход из аккаунта)
  void reset() {
    salonAllowsScheduleEditing = true;
    _seedWeek();
  }

  /// ТЗ, раздел 6: мастер меняет рабочее время и выходные, только если салон разрешил.
  /// [BACKEND NOTE]: придёт из настроек салона (S-04).
  bool salonAllowsScheduleEditing = true;

  final Map<int, DaySchedule> _week = {};

  DaySchedule getDay(int weekday) => _week[weekday]!;

  /// График по умолчанию для мастеров, у которых в моках нет своего кабинета, и для салонов без мастеров:
  /// ежедневно 10:00 – 21:00, часовые слоты, без перерывов.
  /// [BACKEND NOTE]: GET /api/v1/masters/:id/schedule
  static final DaySchedule defaultDay = const DaySchedule(
    isWorking: true,
    workHours: TimeRange(600, 1260),
    breaks: [],
    slots: [],
  ).regenerateSlots();

  /// График мастера на день недели: свой — у владельца кабинета, у остальных — по умолчанию
  DaySchedule dayFor(String masterId, int weekday) =>
      masterId == AppStateService().masterId ? getDay(weekday) : defaultDay;

  /// Сменить только признак «рабочий день» (остальные несохранённые правки не затрагиваются)
  void setDayWorking(int weekday, bool isWorking) {
    _week[weekday] = _week[weekday]!.copyWith(isWorking: isWorking);
  }

  void saveDay(int weekday, DaySchedule schedule) => _week[weekday] = schedule;

  void copyDayTo(DaySchedule source, Iterable<int> weekdays) {
    for (final w in weekdays) {
      _week[w] = source.copyWith();
    }
  }

  void setWorkingDays(Set<int> workingWeekdays) {
    for (final entry in _week.entries.toList()) {
      _week[entry.key] = entry.value.copyWith(isWorking: workingWeekdays.contains(entry.key));
    }
  }

  Set<int> get workingWeekdays => _week.entries.where((e) => e.value.isWorking).map((e) => e.key).toSet();

  static const templates = [
    MasterTemplate('Полный день', '09:00 – 19:00, перерыв 13:00 – 14:00', TimeRange(540, 1140), [TimeRange(780, 840)]),
    MasterTemplate('Утренняя смена', '08:00 – 14:00, без перерыва', TimeRange(480, 840), []),
    MasterTemplate('Вечерняя смена', '14:00 – 21:00, перерыв 17:00 – 17:30', TimeRange(840, 1260), [
      TimeRange(1020, 1050),
    ]),
  ];

  // ---- Брони, визиты и доход: проекции BookingStore ----

  String get _ownMasterId => AppStateService().masterId;

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Брони мастера на дату (все статусы), по времени
  List<MasterAppointment> appointmentsForDate(DateTime date) {
    final list = BookingStore().forMaster(_ownMasterId).where((b) => _sameDay(b.startsAt, date)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list.map(MasterAppointment.fromBooking).toList();
  }

  /// ТЗ: мастер видит брони на сегодня и завтра
  List<MasterAppointment> getAppointments({required bool tomorrow}) =>
      appointmentsForDate(AppClock.now().add(Duration(days: tomorrow ? 1 : 0)));

  /// Выполненные (подтверждённые по QR) визиты мастера за месяц: 0 — текущий, 1 — прошлый. Свежие сверху.
  List<MasterVisitIncome> visitsForMonth(int monthOffset) {
    final now = AppClock.now();
    final month = DateTime(now.year, now.month - monthOffset);
    final visits =
        BookingStore()
            .forMaster(_ownMasterId)
            .where(
              (b) =>
                  b.status == BookingStatus.completed &&
                  b.startsAt.year == month.year &&
                  b.startsAt.month == month.month,
            )
            .toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return visits
        .map((b) => MasterVisitIncome(b.serviceName, b.clientName, b.startsAt, b.sumPrice, b.paymentMethod))
        .toList();
  }

  int revenueForMonth(int monthOffset) => visitsForMonth(monthOffset).fold(0, (sum, v) => sum + v.sum);

  /// Выручка за день: сумма выполненных визитов
  int revenueForDay(DateTime day) => BookingStore()
      .forMaster(_ownMasterId)
      .where((b) => b.status == BookingStatus.completed && _sameDay(b.startsAt, day))
      .fold(0, (sum, b) => sum + b.sumPrice);

  final List<MasterNotification> notifications = const [
    MasterNotification(
      title: 'Новая запись',
      body: 'Дилноза Юсупова · Ламинирование ресниц с ботоксом · завтра 09:00',
      timeAgo: '5 мин назад',
    ),
    MasterNotification(
      title: 'Отмена записи',
      body: 'Нилуфар Рахимова отменила запись на сегодня 16:00',
      timeAgo: '40 мин назад',
      isCancellation: true,
    ),
    MasterNotification(
      title: 'Новая запись',
      body: 'Камила Ахмедова · Архитектура бровей + окрашивание · завтра 11:00',
      timeAgo: '2 ч назад',
    ),
  ];

  // ---- Выплаты мастеру (мок до появления GET /api/v1/masters/me/payouts) ----

  /// История выплат мастеру
  final List<MasterPayout> payouts = [
    MasterPayout(DateTime(AppClock.now().year, AppClock.now().month, 1), 1116000, 'Перевод на карту ···· 8812'),
    MasterPayout(DateTime(AppClock.now().year, AppClock.now().month - 1, 1), 982000, 'Перевод на карту ···· 8812'),
    MasterPayout(DateTime(AppClock.now().year, AppClock.now().month - 2, 1), 1043000, 'Перевод на карту ···· 8812'),
  ];
}

class MasterVisitIncome {
  final String serviceName;
  final String clientName;
  final DateTime date;
  final int sum;
  final String paymentMethod;

  const MasterVisitIncome(this.serviceName, this.clientName, this.date, this.sum, this.paymentMethod);
}

class MasterPayout {
  final DateTime date;
  final int amount;
  final String method;

  const MasterPayout(this.date, this.amount, this.method);
}
