import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
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
  final _appState = AppStateService();
  int _secondsLeft = AppStateService.qrLifetimeSeconds;
  Timer? _timer;
  late String _qrToken;

  @override
  void initState() {
    super.initState();
    _qrToken = _appState.visitQrToken(widget.booking);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _qrToken = _appState.visitQrToken(widget.booking);
          _secondsLeft = AppStateService.qrLifetimeSeconds;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
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
              const Text(
                'Ваш QR-код для визита',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
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
                  border: Border.all(color: const Color(0xFFF3DCE8), width: 1.5),
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
                    QrImageView(
                      data: _qrToken,
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          Text(
                            '${b.date}, ${b.time} · ${b.masterName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const Text(
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
