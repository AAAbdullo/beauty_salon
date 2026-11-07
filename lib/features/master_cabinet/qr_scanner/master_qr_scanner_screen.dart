import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/app_state_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_gradient_button.dart';

class MasterQrScannerScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MasterQrScannerScreen({super.key, required this.onBack});

  @override
  State<MasterQrScannerScreen> createState() => _MasterQrScannerScreenState();
}

class _MasterQrScannerScreenState extends State<MasterQrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  int _stateView = 0; // 0: Видоискатель, 1: Успех, 2: Ошибка

  String _scannedClientName = '';
  String _scannedServiceName = '';
  String _scannedTime = '';
  String _scannedPaymentMethod = '';
  String _errorMessage = '';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_stateView != 0) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _processScannedCode(value);
        break;
      }
    }
  }

  /// Проверка QR по правилам ТЗ: формат, 60-секундный срок, салон, окно −30/+60 мин
  void _processScannedCode(String rawCode, {bool ignoreTimeWindow = false}) {
    final appState = AppStateService();
    final result = appState.validateVisitQr(rawCode, ignoreTimeWindow: ignoreTimeWindow);
    final booking = result.booking;
    setState(() {
      if (booking != null) {
        _scannedClientName = appState.clientName.isNotEmpty ? appState.clientName : 'Клиент';
        _scannedServiceName = booking.serviceName;
        _scannedTime = '${booking.date}, ${booking.time}';
        _scannedPaymentMethod = booking.isPaidWithCredits
            ? '${booking.paymentMethod} · ${booking.credits} кр.'
            : booking.paymentMethod;
        _stateView = 1;
      } else {
        _errorMessage = result.error ?? 'Код не распознан.';
        _stateView = 2;
      }
    });
  }

  /// Демо для симулятора (камеры нет): «клиент» показывает QR ближайшей записи в этот салон
  void _simulateClientQr() {
    final appState = AppStateService();
    final candidates = appState.activeBookings.where((b) => b.salonName == appState.masterSalon);
    if (candidates.isEmpty) {
      setState(() {
        _errorMessage = 'Нет активных записей в салон ${appState.masterSalon} для проверки.';
        _stateView = 2;
      });
      return;
    }
    _processScannedCode(appState.visitQrToken(candidates.first), ignoreTimeWindow: true);
  }

  @override
  Widget build(BuildContext context) {
    // Камера (MobileScanner) всегда остаётся в дереве: результат показывается поверх неё.
    // Если удалять виджет камеры и запускать её заново вручную, на iOS stop/start
    // идут одновременно и блокируют главный поток — приложение зависает.
    // Пока открыт результат, новые коды игнорируются в _onDetect.
    return Stack(
      children: [
        _buildScannerView(),
        if (_stateView == 1) Positioned.fill(child: _buildSuccessView()),
        if (_stateView == 2) Positioned.fill(child: _buildErrorView()),
      ],
    );
  }

  Widget _buildScannerView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Сканирование QR',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? AppColors.gold : AppColors.ink,
            ),
            tooltip: 'Фонарик',
            onPressed: () async {
              try {
                await _scannerController.toggleTorch();
                if (mounted) setState(() => _isTorchOn = !_isTorchOn);
              } catch (_) {
                // Фонарика нет (симулятор / фронтальная камера) — просто игнорируем
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: AppColors.primary),
            tooltip: 'Сменить камеру',
            onPressed: () async {
              try {
                await _scannerController.switchCamera();
              } catch (_) {
                // Камера недоступна (симулятор) — переключать нечего
              }
            },
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                'Отсканируйте живой QR-код клиента для подтверждения визита',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const Spacer(),
              // Реальная камера видоискателя сканера
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) {
                            return Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.all(16),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 40),
                                    SizedBox(height: 8),
                                    Text(
                                      'Камера недоступна (симулятор)\nВоспользуйтесь кнопками теста ниже',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Уголки видоискателя
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFFECEF), borderRadius: BorderRadius.circular(16)),
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
              // Кнопки симуляции для быстрого тестирования на симуляторе
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _simulateClientQr, child: const Text('Демо: QR клиента')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _processScannedCode('GZL|unknown|${DateTime.now().millisecondsSinceEpoch}'),
                      child: const Text('Демо: чужой код'),
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
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
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
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Клиент', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Row(
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  AppStateService().clientAvatar,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.person, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _scannedClientName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Услуга', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _scannedServiceName,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Запись', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _scannedTime,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF3DCE8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Оплата', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _scannedPaymentMethod,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
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
                  onPressed: () {
                    setState(() => _stateView = 0);
                  },
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
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(color: Color(0xFFFFECEF), shape: BoxShape.circle),
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
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AppGradientButton(
                  text: 'Попробовать снова',
                  onPressed: () {
                    setState(() => _stateView = 0);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
