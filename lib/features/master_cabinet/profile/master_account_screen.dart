import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../../core/l10n/app_text.dart';
import '../../../core/data/app_scope.dart';
import '../../../core/data/repositories/master_cabinet_repository.dart';
import '../../../core/data/repository_exception.dart';
import '../../../core/services/masters_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/avatars/avatar_image.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../profile_settings/profile_sheets.dart';

/// Вкладка «Профиль» кабинета мастера (ТЗ, раздел 6 «Usta»):
/// данные мастера, показатели месяца, быстрые переходы, настройки и выход.
class MasterAccountScreen extends StatefulWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const MasterAccountScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenEarnings,
    required this.onOpenScanner,
    required this.onOpenReviews,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  State<MasterAccountScreen> createState() => _MasterAccountScreenState();
}

class _MasterAccountScreenState extends State<MasterAccountScreen> {
  // Профиль мастера (специализация, рейтинг) приходит из каталога; пока он грузится — нейтральные подписи
  MasterProfileModel? _profileData;

  // Показатели месяца: пока грузятся или при сбое — прочерк
  MasterAccountStats? _stats;
  late final _appState = AppScope.read(context).appState;

  @override
  void initState() {
    super.initState();
    _appState.bookingChanges.addListener(_loadStats);
    unawaited(_loadProfile());
    unawaited(_loadStats());
  }

  @override
  void dispose() {
    _appState.bookingChanges.removeListener(_loadStats);
    super.dispose();
  }

  int _statsLoadId = 0; // ответ на устаревший запрос игнорируется

  Future<void> _loadStats() async {
    final id = ++_statsLoadId;
    try {
      final stats = await AppScope.read(context).masterCabinet.accountStats();
      if (mounted && id == _statsLoadId) setState(() => _stats = stats);
    } on RepositoryException {
      // Остаёмся с прочерками; данные подтянутся при следующем изменении записей
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AppScope.read(context).catalog.getMaster(AppScope.read(context).appState.masterId);
      if (mounted) setState(() => _profileData = profile);
    } on RepositoryException {
      // Остаёмся с подписями по умолчанию
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.read(context).appState;
    final stats = _stats;
    final profile = _profileData;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final workingDays = stats?.workingDays;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(gradient: AppGradients.page),
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Профиль мастера',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Нажатие на фото — смена фото профиля (галерея, камера, удаление)
                      GestureDetector(
                        onTap: () => ProfileSheets.changePhoto(context, master: true),
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
                                  image: avatarProvider(appState.masterAvatar),
                                  width: 74,
                                  height: 74,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.person, size: 44, color: AppColors.primary),
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
                              appState.masterName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.specialty ?? 'Мастер салона',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.storefront, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  appState.masterSalon,
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                      _stat('${stats?.visitsThisMonth ?? '—'}', 'Визитов за месяц', Icons.check_circle_outline),
                      const SizedBox(width: 8),
                      _stat('${workingDays ?? '—'}', 'Рабочих дней', Icons.event_available_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    onTap: widget.onOpenEarnings,
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Доход за месяц', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text(
                                stats == null ? '—' : Formatters.formatSum(stats.revenueThisMonth),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Комиссия салона ${appState.salonCommissionPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _tile(Icons.access_time, 'Рабочий график', widget.onOpenSchedule),
                        _divider(),
                        _tile(Icons.qr_code_scanner, 'Сканер визитов', widget.onOpenScanner),
                        _divider(),
                        _tile(Icons.bar_chart_outlined, 'Доход и выплаты', widget.onOpenEarnings),
                        _divider(),
                        _tile(Icons.star_outline_rounded, 'Отзывы', widget.onOpenReviews),
                        _divider(),
                        _tile(Icons.help_outline, 'Поддержка', () => ProfileSheets.support(context)),
                        _divider(),
                        _tile(Icons.settings_outlined, 'Настройки', widget.onOpenSettings),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: AppColors.soft(const Color(0xFFFFF0F5)),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => ProfileSheets.confirmLogout(context, widget.onLogout),
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
              style: TextStyle(fontSize: 10, color: AppColors.muted),
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
      trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 0.5, indent: 56, endIndent: 16, color: AppColors.line);
}
