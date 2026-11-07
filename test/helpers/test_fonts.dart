import 'dart:io';
import 'package:flutter/services.dart';

/// Реальные метрики шрифта вместо тестового «квадратного» (Ahem): иначе проверки вёрстки
/// (переполнения) дают ложные срабатывания. Шрифты берутся из SDK Flutter.
Future<void> loadTestFonts() async {
  // flutter_tester лежит внутри SDK: <flutter>/bin/cache/artifacts/engine/...
  final exe = Platform.resolvedExecutable;
  final cacheIndex = exe.indexOf('${Platform.pathSeparator}bin${Platform.pathSeparator}cache');
  if (cacheIndex == -1) return;
  final fontsDir = '${exe.substring(0, cacheIndex)}/bin/cache/artifacts/material_fonts';
  if (!File('$fontsDir/Roboto-Regular.ttf').existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
    final bytes = File('$fontsDir/Roboto-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(File('$fontsDir/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await icons.load();
}
