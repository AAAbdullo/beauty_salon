import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Мягкая розовая кнопка («Записаться», «Применить») со спецификацией ~83×27 dp
class AppPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double fontSize;

  const AppPillButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 28.0,
    this.fontSize = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: backgroundColor ?? AppColors.primaryTint,
        borderRadius: BorderRadius.circular((height ?? 28) / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular((height ?? 28) / 2),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor ?? AppColors.primaryText,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
