import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/data/app_dependencies.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repositories/visit_qr_repository.dart';
import '../../core/data/repository_exception.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/clock.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/sheets/app_sheet.dart';

/// Личный динамический QR визита (ТЗ M-11): привязан к записи, обновляется каждые 60 секунд.
class ClientQrModal extends StatefulWidget {
  final BookingItem booking;

  const ClientQrModal({super.key, required this.booking});

  static Future<void> show(BuildContext context, {required BookingItem booking}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientQrModal(booking: booking),
    );
  }

  /// QR ближайшего активного визита; если записей нет — подсказка записаться
  static void showForNearestBooking(BuildContext context, {VoidCallback? onBookNew}) {
    final booking = AppStateService().nearestActiveBooking;
    if (booking != null) {
      show(context, booking: booking);
      return;
    }
    showAppSheet<void>(
      context: context,
      title: 'Нет активных записей',
      subtitle: 'QR-код появляется для конкретного визита — запишитесь в салон, и он будет здесь.',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AppGradientButton(
          text: 'Найти салон',
          onPressed: () {
            Navigator.pop(ctx);
            onBookNew?.call();
          },
        ),
      ),
    );
  }

  @override
  State<ClientQrModal> createState() => _ClientQrModalState();
}

class _ClientQrModalState extends State<ClientQrModal> {
  late final AppDependencies _deps;
  final _appState = AppStateService();
  Timer? _timer;

  /// Актуальная версия записи из стора (перенос меняет время, отмена и подтверждение — статус)
  late BookingItem _booking = widget.booking;

  // Токен выдаёт и подписывает сервер; код живёт 60 секунд и обновляется до истечения
  VisitQrToken? _token;
  int _secondsLeft = 0;
  bool _refreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _deps = AppScope.read(context);
    _appState.addListener(_onBookingChanged);
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _appState.removeListener(_onBookingChanged);
    _timer?.cancel();
    super.dispose();
  }

  /// Запись отменили или визит уже подтвердили — код показывать нельзя; перенесли — обновляем время
  void _onBookingChanged() {
    if (!mounted) return;
    final current = _appState.bookingById(widget.booking.id);
    if (current == null || current.status != BookingStatus.active) {
      final message = current?.status == BookingStatus.completed
          ? 'Визит подтверждён'
          : 'Запись отменена — QR-код больше не действует';
      Navigator.of(context).maybePop();
      showAppSnack(context, message);
      return;
    }
    if (current.startsAt != _booking.startsAt) setState(() => _booking = current);
  }

  /// Оставшееся время — до срока, который назвал сервер; по истечении запрашиваем новый код
  void _tick() {
    final token = _token;
    if (!mounted || token == null) return;
    final left = token.expiresAt.difference(AppClock.now()).inSeconds;
    if (left > 0) {
      setState(() => _secondsLeft = left);
    } else {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final token = await _deps.visitQr.issueToken(_booking.id);
      if (!mounted) return;
      setState(() {
        _token = token;
        _secondsLeft = token.expiresAt.difference(AppClock.now()).inSeconds.clamp(0, 1 << 30);
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _token = null; // устаревший код показывать нельзя
        _error = e;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSheetHandle(),
              const SizedBox(height: 18),
              Text(
                'Ваш QR-код для визита',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Покажите этот код администратору или мастеру в салоне',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // Карточка с QR-кодом
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_token != null)
                      QrImageView(
                        data: _token!.value,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.ink,
                        ),
                      )
                    else
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: AsyncSection(
                          isLoading: _error == null,
                          error: _error,
                          onRetry: () => unawaited(_refresh()),
                          minHeight: 200,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (_token != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Обновится через 00:${_secondsLeft.toString().padLeft(2, "0")}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.salonName} · ${b.serviceName}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          Text(
                            '${b.date}, ${b.time} · ${b.masterName}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          Text(
                            'Скриншот не подойдёт: код действует 60 секунд. '
                            'Подтвердить визит можно за 30 мин до начала и до 60 мин после.',
                            style: TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppGradientButton(text: 'Закрыть', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
