/// Мок-репозиторий кабинета мастера (раздел «Usta» в ТЗ).
///
/// Время хранится в минутах от начала суток (540 = 09:00).
/// [BACKEND NOTE]: При подключении NestJS:
///   GET  /api/v1/masters/me/schedule           — недельный график
///   PUT  /api/v1/masters/me/schedule/:weekday  — сохранить день
///   GET  /api/v1/masters/me/appointments?date= — брони на дату
///   GET  /api/v1/masters/me/notifications      — новые брони / отмены
library;

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

  ScheduleSlot copyWith({TimeRange? range, bool? enabled, bool? isCustom}) => ScheduleSlot(
        range: range ?? this.range,
        enabled: enabled ?? this.enabled,
        isCustom: isCustom ?? this.isCustom,
      );
}

class DaySchedule {
  final bool isWorking;
  final TimeRange workHours;
  final List<TimeRange> breaks;
  final List<ScheduleSlot> slots;

  const DaySchedule({
    required this.isWorking,
    required this.workHours,
    required this.breaks,
    required this.slots,
  });

  DaySchedule copyWith({
    bool? isWorking,
    TimeRange? workHours,
    List<TimeRange>? breaks,
    List<ScheduleSlot>? slots,
  }) =>
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
    final custom = slots.where((s) =>
        s.isCustom && !generated.any((g) => g.range.start == s.range.start));
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

class MasterAppointment {
  final String clientName;
  final String serviceName;
  final TimeRange time;
  final String status; // 'Подтверждено' | 'Ожидает' | 'Отменено'
  final String? clientAvatar;

  const MasterAppointment({
    required this.clientName,
    required this.serviceName,
    required this.time,
    required this.status,
    this.clientAvatar,
  });

  bool get isCancelled => status == 'Отменено';
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

class MasterCabinetRepository {
  static final MasterCabinetRepository _instance = MasterCabinetRepository._internal();
  factory MasterCabinetRepository() => _instance;
  MasterCabinetRepository._internal() {
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

  /// ТЗ, раздел 6: мастер меняет рабочее время и выходные, только если салон разрешил.
  /// [BACKEND NOTE]: придёт из настроек салона (S-04).
  bool salonAllowsScheduleEditing = true;

  final Map<int, DaySchedule> _week = {};

  DaySchedule getDay(int weekday) => _week[weekday]!;

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
    MasterTemplate('Вечерняя смена', '14:00 – 21:00, перерыв 17:00 – 17:30', TimeRange(840, 1260), [TimeRange(1020, 1050)]),
  ];

  // ---- Брони мастера (ТЗ: «брони на сегодня и завтра») ----

  final List<MasterAppointment> _today = const [
    MasterAppointment(
      clientName: 'Алина Каримова',
      serviceName: 'Маникюр классический',
      time: TimeRange(600, 690),
      status: 'Подтверждено',
    ),
    MasterAppointment(
      clientName: 'Мадина Турсунова',
      serviceName: 'Окрашивание бровей',
      time: TimeRange(720, 780),
      status: 'Подтверждено',
    ),
    MasterAppointment(
      clientName: 'Санобар Алиева',
      serviceName: 'Стрижка женская',
      time: TimeRange(840, 930),
      status: 'Ожидает',
    ),
    MasterAppointment(
      clientName: 'Нилуфар Рахимова',
      serviceName: 'Покрытие гель-лак',
      time: TimeRange(960, 1050),
      status: 'Отменено',
    ),
  ];

  final List<MasterAppointment> _tomorrow = const [
    MasterAppointment(
      clientName: 'Дилноза Юсупова',
      serviceName: 'Маникюр + покрытие',
      time: TimeRange(570, 660),
      status: 'Подтверждено',
    ),
    MasterAppointment(
      clientName: 'Камила Ахмедова',
      serviceName: 'Педикюр',
      time: TimeRange(690, 780),
      status: 'Подтверждено',
    ),
  ];

  List<MasterAppointment> getAppointments({required bool tomorrow}) => tomorrow ? _tomorrow : _today;

  final List<MasterNotification> notifications = const [
    MasterNotification(
      title: 'Новая запись',
      body: 'Дилноза Юсупова · Маникюр + покрытие · завтра 09:30',
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
      body: 'Камила Ахмедова · Педикюр · завтра 11:30',
      timeAgo: '2 ч назад',
    ),
  ];
}
