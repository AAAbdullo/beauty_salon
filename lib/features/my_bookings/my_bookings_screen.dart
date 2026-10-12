import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../client_qr/client_qr_modal.dart';

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить запись?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          'При отмене более чем за 4 часа до визита ${booking.paymentMethod == "Кредиты" ? "вам вернется ${booking.credits} кредитов." : "деньги вернутся полностью."}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
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
              _appState.cancelBooking(booking.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Запись отменена. Кредиты возвращены на баланс.')),
              );
            },
            child: const Text('Отменить', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                          onPressed: () => _confirmCancel(b),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF3DCE8)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                          label: const Text('Отменить', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => ClientQrModal.show(context, bookingTitle: b.serviceName, salonName: b.salonName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.qr_code, size: 16, color: Colors.white),
                          label: const Text('QR визита', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
