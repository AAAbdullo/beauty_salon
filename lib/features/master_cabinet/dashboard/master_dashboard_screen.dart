import 'package:flutter/material.dart';
import '../../../core/services/app_state_service.dart';
import '../../../core/services/master_cabinet_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_pill_button.dart';
import '../../../core/widgets/cards/app_card.dart';

class MasterDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenEarnings;
  final VoidCallback onScanQr;

  const MasterDashboardScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenEarnings,
    required this.onScanQr,
  });

  @override
  State<MasterDashboardScreen> createState() => _MasterDashboardScreenState();
}

class _MasterDashboardScreenState extends State<MasterDashboardScreen> {
  final _repo = MasterCabinetRepository();

  /// ТЗ, раздел 6: мастер видит брони на сегодня и завтра.
  bool _showTomorrow = false;

  VoidCallback get onOpenSchedule => widget.onOpenSchedule;
  VoidCallback get onOpenEarnings => widget.onOpenEarnings;
  VoidCallback get onScanQr => widget.onScanQr;

  int _activeCount({required bool tomorrow}) =>
      _repo.getAppointments(tomorrow: tomorrow).where((a) => !a.isCancelled).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildMasterHeader(),
                const SizedBox(height: 16),
                _buildMetricsRow(),
                const SizedBox(height: 20),
                _buildNextClientCard(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildTodayAppointments(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.ink, size: 24),
                onPressed: _openNotifications,
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text('${_repo.notifications.length}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.ink, size: 24),
            onPressed: onScanQr,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterHeader() {
    final appState = AppStateService();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    appState.masterAvatar,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.primaryTint,
                      child: const Icon(Icons.person, color: AppColors.primary, size: 44),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(appState.masterName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(width: 4),
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                ],
              ),
              SizedBox(height: 2),
              const Text('Мастер маникюра', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text('${appState.masterSalon} >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Сегодня ${_activeCount(tomorrow: false)} записей', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    final metrics = [
      {'val': '${_activeCount(tomorrow: false)}', 'label': 'Записи\nсегодня', 'icon': Icons.calendar_today_outlined},
      {'val': '${_activeCount(tomorrow: true)}', 'label': 'Записи\nзавтра', 'icon': Icons.event_outlined},
      {'val': '24', 'label': 'Клиенты\nв этом месяце', 'icon': Icons.people_outline},
      {'val': '2 450 000', 'label': 'Выручка\nсегодня (сум)', 'icon': Icons.bar_chart_outlined, 'action': onOpenEarnings},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: metrics.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: m['action'] as VoidCallback?,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    children: [
                      Icon(m['icon'] as IconData, size: 18, color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(m['val'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(m['label'] as String, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNextClientCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ближайший клиент', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFECEF), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Через 20 мин', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryTint,
                      child: Icon(Icons.person, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Алина Каримова', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('Маникюр классический', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: AppColors.muted),
                              SizedBox(width: 4),
                              Text('10:00 – 11:30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.location_on_outlined, size: 12, color: AppColors.muted),
                              SizedBox(width: 2),
                              Text('Nur Beauty', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        text: 'Принять',
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                        height: 38,
                        onPressed: onScanQr,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppPillButton(
                        text: 'Перенести',
                        backgroundColor: AppColors.primaryTint,
                        textColor: AppColors.primaryText,
                        height: 38,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Расписание', 'sub': 'Управлять записями', 'icon': Icons.calendar_month, 'tap': onOpenSchedule},
      {'title': 'Открыть время', 'sub': 'Добавить свободное время', 'icon': Icons.access_time, 'tap': onOpenSchedule},
      {'title': 'Доход', 'sub': 'История выплат и баланс', 'icon': Icons.payments_outlined, 'tap': onOpenEarnings},
      {'title': 'Услуги', 'sub': 'Управлять услугами', 'icon': Icons.grid_view, 'tap': () {}},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Быстрые действия', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: actions.map((a) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: a['tap'] as VoidCallback?,
                    borderRadius: BorderRadius.circular(16),
                    child: AppCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a['icon'] as IconData, size: 20, color: AppColors.primary),
                          const SizedBox(height: 6),
                          Text(a['title'] as String, maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          Text(a['sub'] as String, maxLines: 2, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAppointments() {
    final list = _repo.getAppointments(tomorrow: _showTomorrow);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_showTomorrow ? 'Записи на завтра' : 'Сегодняшние записи',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              _dayChip('Сегодня', !_showTomorrow, () => setState(() => _showTomorrow = false)),
              const SizedBox(width: 6),
              _dayChip('Завтра', _showTomorrow, () => setState(() => _showTomorrow = true)),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Записей нет', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          ...list.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: item.isCancelled ? 0.55 : 1,
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryTint,
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${formatMinutes(item.time.start)}\n${formatMinutes(item.time.end)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(item.serviceName, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (item.isCancelled || _showTomorrow)
                        _statusLabel(item)
                      else
                        AppPillButton(
                          text: 'Принять',
                          backgroundColor: AppColors.primary,
                          textColor: Colors.white,
                          onPressed: onScanQr,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dayChip(String text, bool selected, VoidCallback onTap) {
    return AppPillButton(
      text: text,
      backgroundColor: selected ? AppColors.primary : AppColors.primaryTint,
      textColor: selected ? Colors.white : AppColors.primaryText,
      onPressed: onTap,
    );
  }

  Widget _statusLabel(MasterAppointment item) {
    final color = item.isCancelled ? const Color(0xFFD64545) : AppColors.successText;
    return Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }

  /// ТЗ, раздел 6: мгновенные уведомления о новых бронях и отменах.
  void _openNotifications() {
    showModalBottomSheet<void>(
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
              const Text('Уведомления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final n in _repo.notifications)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: n.isCancellation ? const Color(0xFFFFECEF) : AppColors.successBg,
                    child: Icon(
                      n.isCancellation ? Icons.event_busy_outlined : Icons.event_available_outlined,
                      color: n.isCancellation ? const Color(0xFFD64545) : AppColors.successText,
                    ),
                  ),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(n.body),
                  trailing: Text(n.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
