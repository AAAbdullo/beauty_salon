import '../../core/data/app_scope.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatars/avatar_image.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/cards/app_card.dart';
import 'profile_sheets.dart';
import '../../core/l10n/app_locale.dart';

/// Профиль клиента: данные, статистика, абонемент, быстрые действия, последние записи
class ClientProfileScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQr;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenNotifications;

  /// Открыть «Мои записи» на вкладке: 0 — активные, 1 — прошедшие
  final ValueChanged<int> onOpenBookings;
  final VoidCallback onOpenCredits;
  final VoidCallback onOpenMap;

  const ClientProfileScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenQr,
    required this.onOpenFavorites,
    required this.onOpenNotifications,
    required this.onOpenBookings,
    required this.onOpenCredits,
    required this.onOpenMap,
  });

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late final _appState = AppScope.read(context).appState;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                _buildUserCard(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildSubscriptionCard(),
                const SizedBox(height: 20),
                _buildQuickActionsGrid(),
                const SizedBox(height: 24),
                _buildRecentBookings(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final unread = _appState.unreadNotificationsCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Профиль',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          IconButton(
            tooltip: tr('Уведомления'),
            onPressed: widget.onOpenNotifications,
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: AppColors.primary,
              label: Text('$unread'),
              child: Icon(Icons.notifications_none_rounded, color: AppColors.ink, size: 24),
            ),
          ),
          IconButton(
            tooltip: tr('QR визита'),
            icon: Icon(Icons.qr_code_2_rounded, color: AppColors.ink, size: 24),
            onPressed: widget.onOpenQr,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ProfileSheets.changePhoto(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: Image(
                      image: avatarProvider(_appState.clientAvatar),
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primaryTint,
                        child: const Icon(Icons.person, size: 45, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const Positioned(right: -2, bottom: -2, child: PhotoEditBadge()),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appState.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(_appState.clientPhone, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.workspace_premium, size: 14, color: AppColors.primaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Тариф ${_appState.subscriptionPlan}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ProfileSheets.editProfile(context),
            child: Row(
              children: [
                Text('Изменить', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = <(String, String, IconData, VoidCallback)>[
      (
        '${_appState.activeBookings.length}',
        'Предстоящих',
        Icons.calendar_today_outlined,
        () => widget.onOpenBookings(0),
      ),
      ('${_appState.completedBookings.length}', 'Визитов', Icons.check_circle_outline, () => widget.onOpenBookings(1)),
      ('${_appState.totalFavoritesCount}', 'Избранных', Icons.favorite_border, widget.onOpenFavorites),
      ('${_appState.clientCredits}', 'Кредитов', Icons.account_balance_wallet_outlined, widget.onOpenCredits),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding - 4),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: s.$4,
                child: Column(
                  children: [
                    Icon(s.$3, size: 18, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(s.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      s.$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final total = _appState.planTotalCredits;
    final used = _appState.usedPlanCredits;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: AppGradients.promo),
          child: InkWell(
            onTap: widget.onOpenCredits,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ваш тариф', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          Text(
                            _appState.subscriptionPlan,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_appState.isFrozen) ...[
                        AppStatusBadge(
                          text: 'Заморожен',
                          backgroundColor: AppColors.soft(const Color(0xFFE3F0FF)),
                          textColor: AppColors.onSoft(const Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Действует до ${_appState.subscriptionExpiry}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : used / total,
                      minHeight: 6,
                      backgroundColor: AppColors.isDark ? Colors.white24 : Colors.white70,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Использовано $used из $total кредитов · осталось ${_appState.clientCredits}',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = <(String, IconData, VoidCallback)>[
      ('Мои записи', Icons.calendar_month_outlined, () => widget.onOpenBookings(0)),
      ('Кредиты и оплата', Icons.credit_card_outlined, widget.onOpenCredits),
      ('Избранное', Icons.favorite_border, widget.onOpenFavorites),
      ('Мои отзывы', Icons.chat_bubble_outline, () => widget.onOpenBookings(1)),
      ('Салоны на карте', Icons.location_on_outlined, widget.onOpenMap),
      ('Вопросы', Icons.quiz_outlined, () => ProfileSheets.faq(context)),
      ('Поддержка', Icons.help_outline, () => ProfileSheets.support(context)),
      ('Настройки', Icons.settings_outlined, widget.onOpenSettings),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final item = actions[index];
          return AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            onTap: item.$3,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$2, size: 22, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentBookings() {
    final recent = [..._appState.activeBookings, ..._appState.completedBookings].take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Недавние записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => widget.onOpenBookings(0),
                child: Row(
                  children: [
                    Text(
                      'Все записи',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.primaryText),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Записей пока нет', style: TextStyle(color: AppColors.muted)),
            ),
          ...recent.map((b) {
            final isActive = b.status == BookingStatus.active;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => widget.onOpenBookings(isActive ? 0 : 1),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        isActive ? Icons.event_available_outlined : Icons.check_circle_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${b.salonName} · ${b.masterName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          Text('${b.date} · ${b.time}', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    isActive
                        ? const AppStatusBadge(text: 'Предстоит')
                        : AppStatusBadge(
                            text: 'Завершено',
                            backgroundColor: AppColors.line,
                            textColor: AppColors.muted,
                          ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
