import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../client_qr/client_qr_modal.dart';
import 'leave_review_modal.dart';
import 'reschedule_booking_modal.dart';

class MyBookingsScreen extends StatefulWidget {
  final VoidCallback onBookNew;

  const MyBookingsScreen({
    super.key,
    required this.onBookNew,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _appState = AppStateService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _appState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _confirmCancel(BookingItem booking) {
    final diff = booking.timeUntilAppointment;
    final int hours = diff.isNegative ? 0 : diff.inHours;
    final int minutes = diff.isNegative ? 0 : (diff.inMinutes % 60);
    final remainingStr = diff.isNegative
        ? 'время визита уже наступило'
        : '$hours ч $minutes мин';

    // Строгое правило сервиса: отмена запрещена, если до визита осталось менее 2 часов (< 120 минут)
    if (!booking.canCancel) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_clock, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Отмена невозможна', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'По правилам сервиса отмена визита разрешена строго не позднее чем за 2 часа до начала записи.',
                style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'До вашего приёма осталось: $remainingStr (менее 2 часов). Запись зафиксирована за мастером, списание подтверждено.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Если осталось >= 2 часов (120 минут)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить запись?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          'До визита осталось $hours ч $minutes мин (более 2 часов).\n\nПри отмене ${booking.paymentMethod == "Кредиты" ? "вам полностью вернутся ${booking.credits} кредитов на баланс." : "деньги вернутся полностью."}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Назад', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFECEF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final ok = _appState.cancelBooking(booking.id);
              Navigator.pop(ctx);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.ink,
                    content: Text('Запись отменена. Кредиты успешно возвращены на баланс.'),
                  ),
                );
              }
            },
            child: const Text('Отменить и вернуть', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои записи', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Активные (${_appState.activeBookings.length})'),
                  Tab(text: 'Прошедшие (${_appState.completedBookings.length})'),
                  Tab(text: 'Отмененные (${_appState.cancelledBookings.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBookingsList(_appState.activeBookings, isActiveTab: true),
            _buildBookingsList(_appState.completedBookings),
            _buildBookingsList(_appState.cancelledBookings),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<BookingItem> items, {bool isActiveTab = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 54, color: AppColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Записей не найдено', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('У вас пока нет визитов в этом разделе', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            if (isActiveTab) ...[
              const SizedBox(height: 16),
              AppPillButton(
                text: 'Записаться в салон',
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                height: 38,
                onPressed: widget.onBookNew,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final b = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(b.salonName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (b.status == 'active')
                      const AppStatusBadge(text: 'Подтверждено')
                    else if (b.status == 'completed')
                      AppStatusBadge(text: 'Завершено', backgroundColor: Colors.grey.shade200, textColor: AppColors.muted)
                    else
                      const AppStatusBadge(text: 'Отменено', backgroundColor: Color(0xFFFFECEF), textColor: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${b.serviceName} · ${b.masterName}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${b.date}, ${b.time}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      b.paymentMethod == 'Кредиты' ? '${b.credits} кр.' : '${b.sumPrice} сум',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                    ),
                  ],
                ),
                if (isActiveTab) ...[
                  const Divider(height: 20, color: Color(0xFFF3DCE8)),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await RescheduleBookingModal.show(context, b);
                            if (res == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.ink,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  content: Text('Запись успешно перенесена на ${b.date}, ${b.time}'),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.edit_calendar_outlined, size: 16, color: AppColors.primary),
                          label: const Text('Перенести', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => ClientQrModal.show(context, bookingTitle: b.serviceName, salonName: b.salonName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.qr_code, size: 16, color: Colors.white),
                          label: const Text('QR визита', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmCancel(b),
                      icon: Icon(
                        b.canCancel ? Icons.close : Icons.lock_clock,
                        size: 14,
                        color: b.canCancel ? AppColors.muted : AppColors.primary,
                      ),
                      label: Text(
                        b.canCancel
                            ? 'Отменить запись (доступно > 2 ч)'
                            : 'Отмена заблокирована (< 2 ч до визита)',
                        style: TextStyle(
                          color: b.canCancel ? AppColors.muted : AppColors.primaryText,
                          fontSize: 11,
                          fontWeight: b.canCancel ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ] else if (b.status == 'completed') ...[
                  const Divider(height: 20, color: Color(0xFFF3DCE8)),
                  if (b.reviewRating != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF3DCE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (sIndex) => Icon(
                                  sIndex < (b.reviewRating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 18,
                                  color: const Color(0xFFFFA800),
                                )),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ваша оценка: ${b.reviewRating}.0',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                              ),
                            ],
                          ),
                          if (b.reviewTags != null && b.reviewTags!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: b.reviewTags!.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF3DCE8)),
                                ),
                                child: Text(tag, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
                              )).toList(),
                            ),
                          ],
                          if (b.reviewComment != null && b.reviewComment!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '«${b.reviewComment}»',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.ink),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final res = await LeaveReviewModal.show(context, b);
                          if (res == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.ink,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: const Text('Спасибо за отзыв! Ваша оценка сохранена.'),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFFA800)),
                          backgroundColor: const Color(0xFFFFF9E6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFA800)),
                        label: const Text(
                          'Оставить отзыв о визите',
                          style: TextStyle(color: Color(0xFFD48200), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
