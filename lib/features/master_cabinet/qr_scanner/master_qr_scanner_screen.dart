import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_gradient_button.dart';

class MasterQrScannerScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MasterQrScannerScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<MasterQrScannerScreen> createState() => _MasterQrScannerScreenState();
}

class _MasterQrScannerScreenState extends State<MasterQrScannerScreen> {
  // Для тестирования и интерактивной демонстрации обоих макетов (Успех / Ошибка)
  int _stateView = 0; // 0: Видоискатель, 1: Успех, 2: Ошибка

  @override
  Widget build(BuildContext context) {
    if (_stateView == 1) return _buildSuccessView();
    if (_stateView == 2) return _buildErrorView();
    return _buildScannerView();
  }

  Widget _buildScannerView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Text('Сканирование QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                'Отсканируйте QR-код клиента для подтверждения визита',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const Spacer(),
              // Рамка видоискателя сканера
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary, width: 3),
                    color: Colors.white24,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2, size: 64, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text('Наведите камеру\nна QR-код', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Код обновляется каждые 60 секунд, скриншот не подойдёт.',
                        style: TextStyle(fontSize: 11, color: AppColors.ink, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Кнопки симуляции для демонстрации обоих экранов
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _stateView = 1),
                      child: const Text('Тест: Успех'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _stateView = 2),
                      child: const Text('Тест: Ошибка'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 50, color: AppColors.success),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Визит подтверждён',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Клиент', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text('Zulfiya R.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Услуга', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text('Маникюр классический', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Запись', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text('16:30', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Оплата', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text('Кредиты', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Салону начислена оплата. Клиенту отправлен запрос на отзыв.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const Spacer(),
                AppGradientButton(
                  text: 'Готово',
                  onPressed: () => setState(() => _stateView = 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFECEF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Код не подошёл',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: AppColors.successBg, child: Icon(Icons.check, size: 16, color: AppColors.success)),
                          SizedBox(width: 12),
                          Expanded(child: Text('Запись в этот салон', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        ],
                      ),
                      Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: AppColors.successBg, child: Icon(Icons.check, size: 16, color: AppColors.success)),
                          SizedBox(width: 12),
                          Expanded(child: Text('Запись на сегодня', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        ],
                      ),
                      Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFECEF), child: Icon(Icons.close, size: 16, color: AppColors.primary)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Время: окно от -30 до +60 минут.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('Запись на 16:30, сейчас 14:10', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AppGradientButton(
                  text: 'Сканировать снова',
                  onPressed: () => setState(() => _stateView = 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
