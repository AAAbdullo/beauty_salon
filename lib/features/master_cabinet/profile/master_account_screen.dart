import 'package:flutter/material.dart';
import '../../../core/services/app_state_service.dart';
import '../../../core/services/master_cabinet_repository.dart';
import '../../../core/services/masters_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../profile_settings/profile_sheets.dart';

/// Вкладка «Профиль» кабинета мастера (ТЗ, раздел 6 «Usta»):
/// данные мастера, показатели месяца, быстрые переходы, настройки и выход.
class MasterAccountScreen extends StatelessWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const MasterAccountScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenEarnings,
    required this.onOpenScanner,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateService();
    final cabinet = MasterCabinetRepository();
    final profile = MastersRepository().findMaster(appState.masterName.split(' ').first);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final workingDays = cabinet.workingWeekdays.length;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(gradient: AppGradients.page),
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Профиль мастера',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            appState.masterAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 44, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.masterName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.specialty ?? 'Мастер салона',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  appState.masterSalon,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _stat('${profile?.rating ?? '—'}', 'Рейтинг', Icons.star_border_rounded),
                      const SizedBox(width: 8),
                      _stat('${cabinet.visitsForMonth(0).length}', 'Визитов за месяц', Icons.check_circle_outline),
                      const SizedBox(width: 8),
                      _stat('$workingDays', 'Рабочих дней', Icons.event_available_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    onTap: onOpenEarnings,
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Доход за месяц', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text(
                                Formatters.formatSum(cabinet.revenueForMonth(0)),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Комиссия салона ${appState.salonCommissionPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _tile(Icons.access_time, 'Рабочий график', onOpenSchedule),
                        _divider(),
                        _tile(Icons.qr_code_scanner, 'Сканер визитов', onOpenScanner),
                        _divider(),
                        _tile(Icons.bar_chart_outlined, 'Доход и выплаты', onOpenEarnings),
                        _divider(),
                        _tile(Icons.help_outline, 'Поддержка', () => ProfileSheets.support(context)),
                        _divider(),
                        _tile(Icons.settings_outlined, 'Настройки', onOpenSettings),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: const Color(0xFFFFF0F5),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => ProfileSheets.confirmLogout(context, onLogout),
                      child: const SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Выйти из аккаунта',
                              style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 0.5, indent: 56, endIndent: 16, color: Color(0xFFF3DCE8));
}
