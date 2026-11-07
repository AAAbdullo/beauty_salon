import 'package:flutter/widgets.dart' as w;
import 'app_locale.dart';

/// Замена `Text` из Flutter: переводит текст на выбранный язык в момент построения.
/// Подключается вместо стандартного: `import 'package:flutter/material.dart' hide Text;` + этот файл.
class Text extends w.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.textScaler,
    this.semanticsLabel,
    this.strutStyle,
    this.textDirection,
    this.locale,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final w.TextStyle? style;
  final w.TextAlign? textAlign;
  final w.TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final w.TextScaler? textScaler;
  final String? semanticsLabel;
  final w.StrutStyle? strutStyle;
  final w.TextDirection? textDirection;
  final w.Locale? locale;
  final w.TextWidthBasis? textWidthBasis;
  final w.TextHeightBehavior? textHeightBehavior;
  final w.Color? selectionColor;

  @override
  w.Widget build(w.BuildContext context) {
    return w.Text(
      tr(data),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      textScaler: textScaler,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      strutStyle: strutStyle,
      textDirection: textDirection,
      locale: locale,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
