import 'package:flutter/material.dart' hide Text;
import '../../../core/data/app_scope.dart';
import '../../../core/data/repositories/master_cabinet_repository.dart';
import '../../../core/l10n/app_text.dart';
import '../../../core/models/booking_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/avatars/avatar_image.dart';
import '../../../core/widgets/badges/app_status_badge.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/states/async_screen.dart';

/// Профиль клиента глазами мастера: открывается из уведомления о записи.
/// Показывает, кто записался, и как этот клиент ходит именно к этому мастеру.
class MasterClientProfileScreen extends StatelessWidget {
  final String clientId;
  final VoidCallback onBack;

  const MasterClientProfileScreen({super.key, required this.clientId, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.read(context).masterCabinet;
    return AsyncScreen<MasterClientProfile?>(
      title: 'Профиль клиента',
      onBack: onBack,
      load: () => repo.clientProfile(clientId),
      builder: (context, profile) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.ink), onPressed: onBack),
          title: Text(
            'Профиль клиента',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppGradients.page),
          child: profile == null ? _notFound() : _content(profile),
        ),
      ),
    );
  }

  Widget _notFound() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'Клиент не найден. Возможно, у вас нет записей этого клиента.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.muted),
      ),
    ),
  );

  Widget _content(MasterClientProfile p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 32),
      children: [
        Center(child: _avatar(p)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _stat('${p.completedVisits}', 'Визитов у вас', Icons.check_circle_outline),
            const SizedBox(width: 8),
            _stat('${p.upcoming.length}', 'Предстоящих', Icons.event_available_outlined),
            const SizedBox(width: 8),
            _stat('${p.cancelledCount}', 'Отмен', Icons.event_busy_outlined),
          ],
        ),
        const SizedBox(height: 22),
        _sectionTitle('Предстоящие записи'),
        if (p.upcoming.isEmpty) _empty('Предстоящих записей нет') else ...p.upcoming.map(_bookingCard),
        const SizedBox(height: 18),
        _sectionTitle('История'),
        if (p.history.isEmpty) _empty('Прошлых записей пока нет') else ...p.history.map(_bookingCard),
      ],
    );
  }

  Widget _avatar(MasterClientProfile p) {
    final avatar = p.avatar;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryTint,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipOval(
        child: avatar == null
            ? const Icon(Icons.person, size: 56, color: AppColors.primary)
            : Image(
                image: avatarProvider(avatar),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person, size: 56, color: AppColors.primary),
              ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.muted)),
  );

  Widget _bookingCard(MasterClientBooking b) {
    final badge = switch (b.status) {
      BookingStatus.active => const AppStatusBadge(text: 'Подтверждено'),
      BookingStatus.completed => AppStatusBadge(
        text: 'Завершено',
        backgroundColor: AppColors.line,
        textColor: AppColors.muted,
      ),
      BookingStatus.cancelled => AppStatusBadge(
        text: 'Отменено',
        backgroundColor: AppColors.soft(const Color(0xFFFFECEF)),
        textColor: AppColors.primary,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.serviceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.dayLabel(b.startsAt)}, ${Formatters.time(b.startsAt)} · ${b.priceLabel}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            badge,
          ],
        ),
      ),
    );
  }
}
