import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Базовая карточка приложения с радиусом 20 dp и мягкой розоватой тенью
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    // Тень — на внешнем контейнере, фон и ripple — на Material,
    // чтобы эффект нажатия был виден поверх фона карточки.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: const Color(0xFFC5238A).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: color ?? AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius, side: border?.top ?? BorderSide.none),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
