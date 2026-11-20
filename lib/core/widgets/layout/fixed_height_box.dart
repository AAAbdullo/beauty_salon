import 'package:flutter/widgets.dart';

/// Потолок масштаба системного шрифта там, где высота блока задана жёстко (нижняя панель, ряды-плитки):
/// выше этого подписи перестали бы помещаться. Остальной интерфейс масштабируется до общего потолка (`maxTextScale`).
const fixedHeightMaxTextScale = 1.3;

/// Блок фиксированной высоты, внутри которого масштаб шрифта ограничен [fixedHeightMaxTextScale].
class FixedHeightBox extends StatelessWidget {
  final double height;
  final Widget child;

  const FixedHeightBox({super.key, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: fixedHeightMaxTextScale,
      child: SizedBox(height: height, child: child),
    );
  }
}
