import 'package:flutter/widgets.dart';

/// Сообщает, что поддерево скрыли или снова показали.
///
/// Скрытые вкладки остаются в дереве (IndexedStack) и обёрнуты в `TickerMode(enabled: false)`.
/// Этот признак и используется: экран, у которого есть фоновая работа (таймер, голос, камера),
/// получает сигнал и может остановить её, пока вкладка не видна.
class TickerModeListener extends StatefulWidget {
  /// `true` — поддерево видимо, `false` — скрыто. Вызывается только при смене, не при первом построении.
  final ValueChanged<bool> onChanged;
  final Widget child;

  const TickerModeListener({super.key, required this.onChanged, required this.child});

  @override
  State<TickerModeListener> createState() => _TickerModeListenerState();
}

class _TickerModeListenerState extends State<TickerModeListener> {
  bool? _enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    final previous = _enabled;
    _enabled = enabled;
    if (previous != null && previous != enabled) {
      // Не в фазе построения: обработчик может менять состояние экрана
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(enabled);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
