import '../../core/data/app_scope.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cards/app_card.dart';

/// Экран «Уведомления»: напоминания о визитах, баланс кредитов, акции, просьбы об отзыве.
/// Тап по уведомлению помечает его прочитанным и ведёт в связанный раздел.
class NotificationsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<AppNotification> onNotificationTap;

  const NotificationsScreen({super.key, required this.onBack, required this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.read(context).appState;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final items = appState.notifications;
        final unread = appState.unreadNotificationsCount;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Уведомления',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: AppColors.surface,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.ink, size: 20),
                  onPressed: onBack,
                ),
              ),
            ),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: appState.markAllNotificationsRead,
                  child: const Text(
                    'Прочитать все',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Text('Пока нет уведомлений', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                )
              : SafeArea(
                  top: false,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return AppCard(
                        padding: const EdgeInsets.all(14),
                        color: n.isRead ? AppColors.surface : AppColors.soft(const Color(0xFFFFF6FB)),
                        border: n.isRead ? null : Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                        onTap: () {
                          appState.markNotificationRead(n.id);
                          onNotificationTap(n);
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle),
                              child: Icon(_iconFor(n.type), color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      if (!n.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.body,
                                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n.timeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  static IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.reminder:
        return Icons.event_available_outlined;
      case AppNotificationType.credits:
        return Icons.account_balance_wallet_outlined;
      case AppNotificationType.promo:
        return Icons.local_offer_outlined;
      case AppNotificationType.review:
        return Icons.star_border_rounded;
    }
  }
}
