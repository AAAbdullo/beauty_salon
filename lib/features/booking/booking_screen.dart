import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Column(
          children: [
            Text('Запись', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            Text('Шаг 2 из 3 · Выбор времени', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('150 000 сум', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('34 кр.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Выберите дату', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Row(
              children: [
                Text('Октябрь 2024', style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ],
            ),
          ],
        ),
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
                onTap: () => setState(() => _selectedDayIndex = index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: AppSizes.dateWidth,
                  height: AppSizes.dateHeight,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
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
                      Text(
                        'Окт',
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? Colors.white70 : AppColors.muted,
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Доступное время', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Время вашего города', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((slot) {
            final isSelected = slot['time'] == _selectedTime;
            return InkWell(
              onTap: () => setState(() => _selectedTime = slot['time']!),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                height: AppSizes.slotHeight,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot['time']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                    Text(
                      slot['cost']!,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? Colors.white70 : AppColors.muted,
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
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Выберите мастера', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Любой мастер >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 105,
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
                  width: 82,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryTint : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.person, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(m['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      Text('★ ${m["rating"]!}', style: const TextStyle(fontSize: 9, color: AppColors.muted)),
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
        const Text('Способ записи', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPayOption(
                index: 0,
                title: 'Кредиты',
                subtitle: '34 кр. · баланс 86',
                icon: Icons.monetization_on_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                index: 1,
                title: 'Онлайн оплата',
                subtitle: 'Карта или Click',
                icon: Icons.credit_card,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                index: 2,
                title: 'В салоне',
                subtitle: 'Наличными',
                icon: Icons.storefront,
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
              text: 'Подтвердить запись · 34 кр.',
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
