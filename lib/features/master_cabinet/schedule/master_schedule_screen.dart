import 'package:flutter/material.dart';
import '../../../core/utils/clock.dart';
import '../../../core/services/master_cabinet_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_gradient_button.dart';
import '../../../core/widgets/cards/app_card.dart';

/// «Рабочий график» мастера (макет photo_8, вариант Б).
///
/// ТЗ, раздел 6 (Usta): мастер меняет рабочее время и выходные, если салон разрешил.
/// S-04: график, перерывы, выходные. Какие слоты открыты под кредиты — решает салон (K-02),
/// поэтому переключатели здесь означают «доступно для записи», а не «доступно за кредиты».
class MasterScheduleScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MasterScheduleScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends State<MasterScheduleScreen> {
  static const _shortDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _fullDays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
  static const _monthsGenitive = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  /// Границы, в которых можно выбирать время (06:00 – 23:00), шаг 30 минут.
  static const _dayMin = 360;
  static const _dayMax = 1380;
  static const _step = 30;

  final _repo = MasterCabinetRepository();

  late final DateTime _today;
  late final DateTime _weekStart;
  late int _selectedWeekday;
  late DaySchedule _draft;
  bool _isDirty = false;

  bool get _canEdit => _repo.salonAllowsScheduleEditing;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _today = DateTime(now.year, now.month, now.day);
    _weekStart = _today.subtract(Duration(days: _today.weekday - 1));
    _selectedWeekday = _today.weekday;
    _draft = _repo.getDay(_selectedWeekday).copyWith();
  }

  DateTime _dateOf(int weekday) => _weekStart.add(Duration(days: weekday - 1));

  void _update(DaySchedule next) => setState(() {
        _draft = next;
        _isDirty = true;
      });

  void _save() {
    _repo.saveDay(_selectedWeekday, _draft);
    setState(() => _isDirty = false);
    _snack('График на ${_fullDays[_selectedWeekday - 1].toLowerCase()} сохранён');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  /// Спрашивает, что делать с несохранёнными изменениями. Возвращает false, если пользователь остался.
  Future<bool> _resolveUnsaved() async {
    if (!_isDirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить изменения?'),
        content: const Text('В графике есть несохранённые изменения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Остаться')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Не сохранять')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == 'save') {
      _save();
      return true;
    }
    if (result == 'discard') {
      setState(() => _isDirty = false);
      return true;
    }
    return false;
  }

  Future<void> _selectDay(int weekday) async {
    if (weekday == _selectedWeekday) return;
    if (!await _resolveUnsaved()) return;
    setState(() {
      _selectedWeekday = weekday;
      _draft = _repo.getDay(weekday).copyWith();
      _isDirty = false;
    });
  }

  Future<void> _handleBack() async {
    if (await _resolveUnsaved()) widget.onBack();
  }

  List<int> _timeOptions(int from, int to) => [for (var t = from; t <= to; t += _step) t];

  // ---------------------------------------------------------------------------
  // Изменение графика
  // ---------------------------------------------------------------------------

  void _setWorkHours(TimeRange hours) {
    // Перерывы, вышедшие за рабочее время, удаляем.
    final breaks = _draft.breaks.where((b) => b.start >= hours.start && b.end <= hours.end).toList();
    _update(_draft.copyWith(workHours: hours, breaks: breaks).regenerateSlots());
  }

  void _setBreak(int index, TimeRange range) {
    final others = [..._draft.breaks]..removeAt(index);
    if (others.any((b) => b.overlaps(range))) {
      _snack('Перерывы не должны пересекаться');
      return;
    }
    final breaks = [..._draft.breaks]..[index] = range;
    breaks.sort((a, b) => a.start.compareTo(b.start));
    _update(_draft.copyWith(breaks: breaks));
  }

  void _removeBreak(int index) {
    _update(_draft.copyWith(breaks: [..._draft.breaks]..removeAt(index)));
  }

  void _addBreak() {
    final hours = _draft.workHours;
    // Ищем первое свободное окно в 30 минут, начиная с середины дня.
    final middle = hours.start + ((hours.end - hours.start) ~/ 2 ~/ _step) * _step;
    final candidates = [
      for (var t = middle; t + _step <= hours.end; t += _step) t,
      for (var t = hours.start; t < middle; t += _step) t,
    ];
    for (final t in candidates) {
      final range = TimeRange(t, t + _step);
      if (!_draft.breaks.any((b) => b.overlaps(range))) {
        final breaks = [..._draft.breaks, range]..sort((a, b) => a.start.compareTo(b.start));
        _update(_draft.copyWith(breaks: breaks));
        return;
      }
    }
    _snack('Нет свободного времени для ещё одного перерыва');
  }

  void _toggleSlot(int index, bool enabled) {
    final slots = [..._draft.slots];
    slots[index] = slots[index].copyWith(enabled: enabled);
    _update(_draft.copyWith(slots: slots));
  }

  void _removeSlot(int index) {
    _update(_draft.copyWith(slots: [..._draft.slots]..removeAt(index)));
  }

  void _applyTemplate(MasterTemplate template) {
    _update(_draft
        .copyWith(isWorking: true, workHours: template.workHours, breaks: List.of(template.breaks))
        .regenerateSlots());
    _snack('Применён шаблон «${template.title}»');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      if (!_canEdit) ...[
                        const SizedBox(height: 12),
                        _buildLockedBanner(),
                      ],
                      const SizedBox(height: 16),
                      _buildDaysRow(),
                      const SizedBox(height: 16),
                      IgnorePointer(
                        ignoring: !_canEdit,
                        child: Opacity(
                          opacity: _canEdit ? 1 : 0.55,
                          child: Column(
                            children: [
                              _buildDayCard(),
                              const SizedBox(height: 14),
                              _buildSlotsCard(),
                              const SizedBox(height: 14),
                              _buildBottomActions(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_canEdit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 4, AppSizes.screenPadding, 110),
                  child: AppGradientButton(
                    text: _isDirty ? 'Сохранить изменения' : 'Изменения сохранены',
                    width: double.infinity,
                    onPressed: _isDirty ? _save : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: Colors.black12,
          child: SizedBox(
            width: AppSizes.backButton,
            height: AppSizes.backButton,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.ink),
              onPressed: _handleBack,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text('Рабочий график', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
            Material(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _canEdit ? _openTemplates : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Шаблоны', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Настройте своё рабочее время и доступные слоты для записи клиентов.',
          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: Color(0xFFB7791F)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Салон не разрешил мастерам менять график. Обратитесь к администратору салона.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A5A12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRow() {
    return Row(
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final date = _dateOf(weekday);
        final isSelected = weekday == _selectedWeekday;
        final isToday = date == _today;
        final isWeekend = weekday >= DateTime.saturday;
        final isWorking = weekday == _selectedWeekday ? _draft.isWorking : _repo.getDay(weekday).isWorking;
        final baseColor = isWeekend ? AppColors.primary : AppColors.ink;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selectDay(weekday),
                child: Opacity(
                  opacity: isWorking || isSelected ? 1 : 0.45,
                  child: SizedBox(
                    height: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shortDays[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white70 : (isWeekend ? AppColors.primary : AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : baseColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? (isSelected ? Colors.white : AppColors.primary) : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayCard() {
    final date = _dateOf(_selectedWeekday);
    final title = '${_fullDays[_selectedWeekday - 1]}, ${date.day} ${_monthsGenitive[date.month - 1]}';
    final hours = _draft.workHours;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Switch(
                value: _draft.isWorking,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (v) => _update(_draft.copyWith(isWorking: v)),
              ),
              Text(
                _draft.isWorking ? 'Рабочий день' : 'Выходной',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          if (!_draft.isWorking) ...[
            const SizedBox(height: 8),
            const Text(
              'В этот день клиенты не смогут к вам записаться.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ] else ...[
            const Divider(height: 20, color: Color(0xFFF3E6EE)),
            const _SectionLabel(icon: Icons.access_time, text: 'Время работы'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    value: hours.start,
                    options: _timeOptions(_dayMin, hours.end - 60),
                    onSelected: (v) => _setWorkHours(hours.copyWith(start: v)),
                  ),
                ),
                const _Dash(),
                Expanded(
                  child: _TimeDropdown(
                    value: hours.end,
                    options: _timeOptions(hours.start + 60, _dayMax),
                    onSelected: (v) => _setWorkHours(hours.copyWith(end: v)),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 14),
            const _SectionLabel(icon: Icons.coffee_outlined, text: 'Перерыв'),
            const SizedBox(height: 8),
            if (_draft.breaks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Без перерыва', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
            for (var i = 0; i < _draft.breaks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeDropdown(
                        value: _draft.breaks[i].start,
                        options: _timeOptions(hours.start, _draft.breaks[i].end - _step),
                        onSelected: (v) => _setBreak(i, _draft.breaks[i].copyWith(start: v)),
                      ),
                    ),
                    const _Dash(),
                    Expanded(
                      child: _TimeDropdown(
                        value: _draft.breaks[i].end,
                        options: _timeOptions(_draft.breaks[i].start + _step, hours.end),
                        onSelected: (v) => _setBreak(i, _draft.breaks[i].copyWith(end: v)),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                        tooltip: 'Удалить перерыв',
                        onPressed: () => _removeBreak(i),
                      ),
                    ),
                  ],
                ),
              ),
            _SoftActionButton(text: 'Добавить перерыв', onPressed: _addBreak),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotsCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'Доступные слоты',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.help_outline, size: 18, color: AppColors.muted),
                onPressed: _showSlotsHelp,
              ),
              const Spacer(),
              if (_draft.isWorking)
                Material(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openAddSlot,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Добавить слот', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!_draft.isWorking)
            const Text('Выходной — слотов нет.', style: TextStyle(fontSize: 13, color: AppColors.muted))
          else ...[
            if (_draft.slots.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Нет слотов. Расширьте время работы или добавьте слот вручную.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
            for (var i = 0; i < _draft.slots.length; i++) _buildSlotRow(i),
            const SizedBox(height: 4),
            _SoftActionButton(text: 'Добавить произвольный слот', onPressed: _openAddSlot),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotRow(int index) {
    final slot = _draft.slots[index];
    final inBreak = _draft.isInBreak(slot.range);
    final isOpen = slot.enabled && !inBreak;
    final statusText = inBreak ? 'Перерыв' : (slot.enabled ? 'Доступно' : 'Закрыто');
    final statusColor = isOpen ? AppColors.success : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: inBreak ? const Color(0xFFF5F3F6) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1E4EC)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: Text(slot.range.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                slot.isCustom ? '$statusText · вручную' : statusText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
            Switch(
              value: isOpen,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              onChanged: inBreak ? null : (v) => _toggleSlot(index, v),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
              onSelected: (action) {
                if (action == 'toggle') _toggleSlot(index, !slot.enabled);
                if (action == 'delete') _removeSlot(index);
              },
              itemBuilder: (_) => [
                if (!inBreak)
                  PopupMenuItem(value: 'toggle', child: Text(slot.enabled ? 'Закрыть слот' : 'Открыть слот')),
                if (slot.isCustom) const PopupMenuItem(value: 'delete', child: Text('Удалить слот')),
                if (inBreak && !slot.isCustom)
                  const PopupMenuItem(enabled: false, child: Text('Слот попадает на перерыв')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.calendar_today_outlined,
            title: 'Копировать на другие дни',
            subtitle: 'Применить этот график к другим дням недели',
            onTap: _openCopyDays,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.settings_outlined,
            title: 'Выходные дни',
            subtitle: 'Управление выходными днями',
            onTap: _openDaysOff,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Модальные окна
  // ---------------------------------------------------------------------------

  void _showSlotsHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Доступные слоты'),
        content: const Text(
          'Слоты строятся по вашему рабочему времени с шагом 1 час. '
          'Выключенный слот закрыт для записи. Слоты, попадающие на перерыв, недоступны.\n\n'
          'Какие из открытых слотов можно оплатить кредитами, определяет салон.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
      ),
    );
  }

  Future<void> _openTemplates() async {
    final template = await showModalBottomSheet<MasterTemplate>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetTitle('Шаблоны графика'),
              const SizedBox(height: 4),
              const Text('Шаблон заменит время работы и перерывы выбранного дня.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              for (final t in MasterCabinetRepository.templates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule, color: AppColors.primary),
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.subtitle),
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (template != null) _applyTemplate(template);
  }

  Future<void> _openAddSlot() async {
    var start = _draft.workHours.end <= _dayMax - 60 ? _draft.workHours.end : _draft.workHours.start;
    var duration = 60;

    final range = await showModalBottomSheet<TimeRange>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetTitle('Новый слот'),
                const SizedBox(height: 4),
                const Text('Например, дополнительное время после конца рабочего дня.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 16),
                const Text('Начало', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                _TimeDropdown(
                  value: start,
                  options: _timeOptions(_dayMin, _dayMax - duration),
                  onSelected: (v) => setSheet(() => start = v),
                ),
                const SizedBox(height: 14),
                const Text('Длительность', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [30, 60, 90, 120].map((d) {
                    return ChoiceChip(
                      label: Text('$d мин'),
                      selected: duration == d,
                      selectedColor: AppColors.primaryTint,
                      onSelected: start + d <= _dayMax ? (_) => setSheet(() => duration = d) : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                AppGradientButton(
                  text: 'Добавить ${formatMinutes(start)} – ${formatMinutes(start + duration)}',
                  width: double.infinity,
                  onPressed: () => Navigator.pop(ctx, TimeRange(start, start + duration)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (range == null) return;

    final conflict = _draft.slots.where((s) => s.range.overlaps(range)).firstOrNull;
    if (conflict != null) {
      _snack('Пересекается со слотом ${conflict.range.label}');
      return;
    }
    if (_draft.isInBreak(range)) {
      _snack('Слот попадает на перерыв');
      return;
    }
    final slots = [..._draft.slots, ScheduleSlot(range: range, isCustom: true)]
      ..sort((a, b) => a.range.start.compareTo(b.range.start));
    _update(_draft.copyWith(slots: slots));
  }

  Future<void> _openCopyDays() async {
    final selected = <int>{};
    final targets = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetTitle('Копировать на другие дни'),
                const SizedBox(height: 4),
                Text(
                  'График дня «${_fullDays[_selectedWeekday - 1]}» заменит график выбранных дней.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                for (var w = 1; w <= 7; w++)
                  if (w != _selectedWeekday)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      value: selected.contains(w),
                      title: Text(_fullDays[w - 1]),
                      onChanged: (v) => setSheet(() => v == true ? selected.add(w) : selected.remove(w)),
                    ),
                const SizedBox(height: 12),
                AppGradientButton(
                  text: 'Применить',
                  width: double.infinity,
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (targets == null || targets.isEmpty) return;

    _repo.copyDayTo(_draft, targets);
    _save();
    _snack('График скопирован на ${targets.length} ${_daysWord(targets.length)}');
  }

  Future<void> _openDaysOff() async {
    final working = _repo.workingWeekdays;
    // Учитываем несохранённое переключение «Рабочий день» у текущего дня.
    _draft.isWorking ? working.add(_selectedWeekday) : working.remove(_selectedWeekday);
    // Что было показано в окне — чтобы сохранить только те дни, которые пользователь реально поменял
    final shown = Set<int>.of(working);

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetTitle('Выходные дни'),
                const SizedBox(height: 4),
                const Text('Отметьте дни, в которые вы не работаете.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 8),
                for (var w = 1; w <= 7; w++)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: Text(_fullDays[w - 1]),
                    subtitle: Text(working.contains(w) ? 'Рабочий день' : 'Выходной'),
                    value: !working.contains(w),
                    onChanged: (isOff) => setSheet(() => isOff ? working.remove(w) : working.add(w)),
                  ),
                const SizedBox(height: 12),
                AppGradientButton(
                  text: 'Сохранить',
                  width: double.infinity,
                  onPressed: () => Navigator.pop(ctx, working),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;

    // Выходные сохраняются сразу, но только как признак «рабочий день» у изменённых дней.
    // Остальные несохранённые правки открытого дня (часы, перерывы, слоты) не сохраняются молча.
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      if (result.contains(weekday) != shown.contains(weekday)) {
        _repo.setDayWorking(weekday, result.contains(weekday));
      }
    }
    if (result.contains(_selectedWeekday) != _draft.isWorking) {
      setState(() => _draft = _draft.copyWith(isWorking: result.contains(_selectedWeekday)));
    }
    _snack('Выходные дни обновлены');
  }

  String _daysWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'дня';
    return 'дней';
  }
}

// -----------------------------------------------------------------------------
// Вспомогательные виджеты
// -----------------------------------------------------------------------------

class _TimeDropdown extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onSelected;

  const _TimeDropdown({required this.value, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: value,
      onSelected: onSelected,
      constraints: const BoxConstraints(maxHeight: 320),
      itemBuilder: (_) => [
        for (final t in options) PopupMenuItem(value: t, height: 40, child: Text(formatMinutes(t))),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(formatMinutes(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('—', style: TextStyle(color: AppColors.muted)),
      );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ],
      );
}

class _SoftActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SoftActionButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String text;

  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink));
}
