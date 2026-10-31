import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';

/// Экран бронирования слота (ТЗ M-08)
/// - Выбор даты (горизонтальный календарь на 7 дней)
/// - Выбор слотов времени
/// - Выбор мастера
/// - Таймер удержания слота на 10 минут (ТЗ: slot 10 daqiqa ushlab turiladi)
class BookingScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPaymentStep;

  const BookingScreen({
    super.key,
    required this.onBack,
    required this.onPaymentStep,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _selectedDayIndex = 0;
  String _selectedTime = '12:00';
  int _selectedMasterIndex = 0;
  int _selectedPaymentMethod = 0; // 0 - Кредиты, 1 - Онлайн, 2 - В салоне

  // ТЗ M-08: Таймер удержания слота на 10 минут (600 секунд)
  Timer? _holdTimer;
  int _holdSecondsLeft = 600; // 10 минут

  final _days = [
    {'day': 'Сб', 'date': '12'},
    {'day': 'Вс', 'date': '13'},
    {'day': 'Пн', 'date': '14'},
    {'day': 'Вт', 'date': '15'},
    {'day': 'Ср', 'date': '16'},
    {'day': 'Чт', 'date': '17'},
    {'day': 'Пт', 'date': '18'},
  ];

  final _timeSlots = [
    {'time': '10:00', 'cost': '34 кр.'},
    {'time': '11:00', 'cost': '34 кр.'},
    {'time': '12:00', 'cost': '34 кр.'},
    {'time': '13:00', 'cost': '34 кр.'},
    {'time': '14:00', 'cost': '34 кр.'},
    {'time': '15:00', 'cost': '34 кр.'},
    {'time': '16:00', 'cost': '34 кр.'},
    {'time': '17:00', 'cost': '34 кр.'},
    {'time': '18:00', 'cost': '41 кр.'},
    {'time': '19:00', 'cost': '41 кр.'},
    {'time': '20:00', 'cost': '41 кр.'},
    {'time': '21:00', 'cost': '41 кр.'},
  ];

  final _masters = [
    {'name': 'Алена', 'rating': '4.9', 'spec': 'Маникюр'},
    {'name': 'Сабина', 'rating': '4.8', 'spec': 'Брови'},
    {'name': 'Дилноза', 'rating': '4.7', 'spec': 'Стрижки'},
    {'name': 'Мадина', 'rating': '4.9', 'spec': 'Косметология'},
  ];

  @override
  void initState() {
    super.initState();
    _startHoldTimer();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHoldTimer() {
    _holdTimer?.cancel();
    setState(() => _holdSecondsLeft = 600); // 10 минут
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_holdSecondsLeft > 0) {
        setState(() => _holdSecondsLeft--);
      } else {
        timer.cancel();
        _showTimeoutDialog();
      }
    });
  }

  void _onSlotSelected(String slotTime) {
    setState(() {
      _selectedTime = slotTime;
    });
    // При смене слота запускаем 10 минут удержания заново
    _startHoldTimer();
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.timer_off_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Время брони истекло', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            '10 минут удержания слота истекли. Пожалуйста, выберите удобное время повторно.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startHoldTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Продлить бронь', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Запись на услугу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHoldTimerBanner(),
                    const SizedBox(height: 14),
                    _buildServiceSummary(),
                    const SizedBox(height: 20),
                    _buildDateSelector(),
                    const SizedBox(height: 20),
                    _buildTimeSlots(),
                    const SizedBox(height: 20),
                    _buildMasterSelector(),
                    const SizedBox(height: 20),
                    _buildPaymentMethodSelector(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildBottomConfirmation(),
          ],
        ),
      ),
    );
  }

  /// ТЗ M-08: Индикатор удержания слота на 10 минут
  Widget _buildHoldTimerBanner() {
    final isLowTime = _holdSecondsLeft < 120;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLowTime ? const Color(0xFFFFECEF) : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowTime ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_filled,
            size: 20,
            color: isLowTime ? Colors.red : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Слот зарезервирован на: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    Text(
                      _formatTimer(_holdSecondsLeft),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isLowTime ? Colors.red : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'ТЗ: слот удерживается 10 минут для оплаты',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummary() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.spa, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Маникюр классический', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text('Nur Beauty · Любой мастер', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: AppColors.muted),
                    SizedBox(width: 4),
                    Text('60 мин', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    SizedBox(width: 8),
                    Icon(Icons.star, size: 13, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text('4.8 (126 отзывов)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final d = _days[index];
              final isSelected = index == _selectedDayIndex;
              return InkWell(
                onTap: () {
                  setState(() => _selectedDayIndex = index);
                  _startHoldTimer();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: AppSizes.dateWidth,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d['day']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d['date']!,
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
      ],
    );
  }

  Widget _buildTimeSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Доступное время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              'Выбрано: $_selectedTime',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((slot) {
            final isSelected = _selectedTime == slot['time'];
            return InkWell(
              onTap: () => _onSlotSelected(slot['time']!),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8),
                    width: 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      slot['time']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot['cost']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMasterSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Мастер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _masters.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final m = _masters[index];
              final isSelected = index == _selectedMasterIndex;
              return InkWell(
                onTap: () => setState(() => _selectedMasterIndex = index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryTint : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 22, color: isSelected ? Colors.white : AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            Text(m['spec']!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 10, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Text(m['rating']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Способ оплаты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPayOption(
                index: 0,
                title: 'Кредиты',
                subtitle: 'Баланс: 86',
                icon: Icons.account_balance_wallet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                index: 1,
                title: 'Онлайн',
                subtitle: 'Click, Payme',
                icon: Icons.credit_card,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                index: 2,
                title: 'В салоне',
                subtitle: 'При визите',
                icon: Icons.store,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayOption({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == index;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary : AppColors.ink)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomConfirmation() {
    final priceLabel = _selectedPaymentMethod == 0 ? '34 кр.' : '150 000 сум';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            AppGradientButton(
              text: 'Подтвердить запись · $priceLabel',
              onPressed: widget.onPaymentStep,
            ),
            const SizedBox(height: 6),
            const Text(
              'Бесплатная отмена за 4 часа до визита',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
