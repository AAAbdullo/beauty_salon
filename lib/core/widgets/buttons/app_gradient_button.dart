import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';

/// Основная брендовая кнопка действия (358 × 48 dp, градиент CTA, скругленные углы 24 dp).
///
/// Если обработчик асинхронный (возвращает `Future`), кнопка сама блокируется и показывает индикатор,
/// пока он не завершится: повторный тап не запустит действие второй раз.
class AppGradientButton extends StatefulWidget {
  final String text;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const AppGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = AppSizes.buttonHeight,
  });

  @override
  State<AppGradientButton> createState() => _AppGradientButtonState();
}

class _AppGradientButtonState extends State<AppGradientButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    final result = widget.onPressed?.call();
    if (result is Future<void>) {
      setState(() => _busy = true); // синхронно, до первого await: второй тап в том же кадре уже заблокирован
      try {
        await result;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final icon = widget.icon;
    final width = widget.width;
    final height = widget.height;
    final isLoading = widget.isLoading || _busy;
    final isEnabled = widget.onPressed != null && !isLoading;

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? AppGradients.cta
            : const LinearGradient(
                colors: [Color(0xFFE0D8DE), Color(0xFFC7BFC5)],
              ),
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: isEnabled ? _handleTap : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        icon,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
