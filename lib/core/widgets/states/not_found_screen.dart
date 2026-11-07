import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buttons/app_gradient_button.dart';

/// Экран «не найдено»: показывается, когда салон, мастер или запись по id не существуют.
/// Вместо подстановки другого объекта пользователь видит понятное сообщение и кнопку «Назад».
class NotFoundScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onBack;

  const NotFoundScreen({super.key, required this.title, required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: onBack,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        padding: const EdgeInsets.all(AppSizes.screenPadding * 1.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              AppGradientButton(text: 'Назад', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}
