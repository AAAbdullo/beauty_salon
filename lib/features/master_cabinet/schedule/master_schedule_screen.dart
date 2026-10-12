import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/badges/app_status_badge.dart';
import '../../../core/widgets/buttons/app_pill_button.dart';
import '../../../core/widgets/cards/app_card.dart';

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
  int _selectedDay = 0;
  bool _isDayOff = false;

  final _days = [
    {'day': 'Пн', 'date': '12'},
    {'day': 'Вт', 'date': '13'},
    {'day': 'Ср', 'date': '14'},
    {'day': 'Чт', 'date': '15'},
    {'day': 'Пт', 'date': '16'},
    {'day': 'Сб', 'date': '17'},
    {'day': 'Вс', 'date': '18'},
  ];

  final List<Map<String, dynamic>> _slots = [
    {'time': '09:00', 'active': false},
    {'time': '10:30', 'active': true},
    {'time': '12:00', 'active': false},
    {'time': '14:00', 'active': true},
    {'time': '15:30', 'active': false},
    {'time': '17:00', 'active': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Text('Расписание', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.ink),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDaysRow(),
              const SizedBox(height: 20),
              _buildWorkHoursCard(),
              const SizedBox(height: 16),
              _buildBreakCard(),
              const SizedBox(height: 20),
              _buildOpenSlotsSection(),
              const SizedBox(height: 24),
              _buildScheduleList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysRow() {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final d = _days[index];
          final isSelected = index == _selectedDay;
          return InkWell(
            onTap: () => setState(() => _selectedDay = index),
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
                  Text(d['day']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white70 : AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(d['date']!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkHoursCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Рабочее время', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
              Row(
                children: [
                  const Text('Выходной', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  Switch(
                    value: _isDayOff,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isDayOff = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Начало', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      Text('09:00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('—', style: TextStyle(color: AppColors.muted)),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Конец', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      Text('18:00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.free_breakfast_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Перерыв', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('13:00 — 14:00', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          AppPillButton(text: 'Изменить', onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildOpenSlotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Открытые слоты', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) {
            final slot = _slots[index];
            final isActive = slot['active'] as bool;
            return InkWell(
              onTap: () => setState(() => slot['active'] = !isActive),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? AppColors.primary : const Color(0xFFF3DCE8)),
                ),
                child: Center(
                  child: Text(
                    slot['time'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Сегодняшние записи', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryTint,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('10:00 · Алина Каримова', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Маникюр классический', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              const Spacer(),
              const AppStatusBadge(text: 'Подтверждено'),
            ],
          ),
        ),
      ],
    );
  }
}
