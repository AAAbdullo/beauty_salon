import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Жест iPhone «назад»: свайп вправо от левого края экрана вызывает [onBack].
///
/// В приложении своя навигация (стек страниц и вкладки, а не системные маршруты), поэтому iOS сам такой жест
/// не даёт. На Android работает системная «Назад», поэтому полоса включается только на iOS и только когда
/// есть куда вернуться ([enabled]).
class EdgeSwipeBack extends StatelessWidget {
  final bool enabled;
  final VoidCallback onBack;
  final Widget child;

  /// Ширина полосы у края, в которой жест начинается (как у системного жеста iOS)
  static const edgeWidth = 20.0;

  /// Сколько нужно протянуть вправо, чтобы жест засчитался
  static const distanceThreshold = 70.0;

  /// Либо достаточно быстрого «броска» вправо
  static const velocityThreshold = 800.0;

  const EdgeSwipeBack({super.key, required this.enabled, required this.onBack, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled || defaultTargetPlatform != TargetPlatform.iOS) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: edgeWidth,
          child: _EdgeStrip(onBack: onBack),
        ),
      ],
    );
  }
}

class _EdgeStrip extends StatefulWidget {
  final VoidCallback onBack;

  const _EdgeStrip({required this.onBack});

  @override
  State<_EdgeStrip> createState() => _EdgeStripState();
}

class _EdgeStripState extends State<_EdgeStrip> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Полоса перехватывает касания у самого края (в том числе над картой), как системный жест
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final fling = (d.primaryVelocity ?? 0) >= EdgeSwipeBack.velocityThreshold;
        if (_dx >= EdgeSwipeBack.distanceThreshold || (fling && _dx > 20)) widget.onBack();
        _dx = 0;
      },
      onHorizontalDragCancel: () => _dx = 0,
    );
  }
}
