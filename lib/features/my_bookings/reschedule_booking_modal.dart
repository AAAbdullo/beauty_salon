import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';

/// Модальное окно переноса времени записи (ТЗ M-10)
class RescheduleBookingModal extends StatefulWidget {
  final BookingItem booking;

  const RescheduleBookingModal({
    super.key,
    required this.booking,
  });

  static Future<bool?> show(BuildContext context, BookingItem booking) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RescheduleBookingModal(booking: booking),
    );
  }

  @override
  State<RescheduleBookingModal> createState() => _RescheduleBookingModalState();
}

class _RescheduleBookingModalState extends State<RescheduleBookingModal> {
  late int _selectedDayIndex;
  late String _selectedTime;
  final _appState = AppStateService();

  late final List<Map<String, dynamic>> _days;
  final List<String> _availableSlots = [
    '09:30',
    '11:00',
    '12:30',
    '14:00',
    '15:30',
    '17:00',
    '18:30',
    '20:00',
  ];

  static const _weekDaysRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _monthNamesRu = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = 0;
    _selectedTime = _availableSlots[1]; // по умолчанию второй слот

    // Генерируем 7 ближайших дней
    final now = DateTime.now();
    _days = List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      final dayName = i == 0
          ? 'Сегодня'
          : (i == 1 ? 'Завтра' : _weekDaysRu[d.weekday - 1]);
      final dateNumber = '${d.day}';
      final formatted = '$dayName, ${d.day} ${_monthNamesRu[d.month - 1]}';
      return {
        'day': dayName,
        'date': dateNumber,
        'formatted': formatted,
        'dateObj': d,
      };
    });
  }

  void _confirmReschedule() {
    final selectedDayStr = _days[_selectedDayIndex]['formatted'] as String;

    // [BACKEND NOTE]: В будущем здесь будет вызов REST API NestJS:
    // PATCH /api/v1/bookings/${widget.booking.id}/reschedule
    // body: { "newDate": selectedDayStr, "newTime": _selectedTime }
    _appState.rescheduleBooking(
      bookingId: widget.booking.id,
      newDate: selectedDayStr,
      newTime: _selectedTime,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Перенос записи',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Выберите новую дату и свободный слот',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Инфо-карточка текущей брони
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3DCE8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.spa_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.booking.serviceName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.booking.salonName} · ${widget.booking.masterName}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Сейчас: ${widget.booking.date}, ${widget.booking.time}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Выбор новой даты
          const Text(
            'Выберите дату',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = _days[index];
                final isSelected = _selectedDayIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE5E5EA),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d['day'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d['date'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Выбор времени
          const Text(
            'Свободное время',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSlots.map((slot) {
              final isSelected = _selectedTime == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryTint : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFE5E5EA),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.primaryText : AppColors.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Пояснение правила отмены / переноса
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Перенос записи выполняется бесплатно. Ваши кредиты сохраняются.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0051A8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Кнопка подтверждения
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _confirmReschedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Перенести на ${_days[_selectedDayIndex]['day']}, $_selectedTime',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
