import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Телефон 390×844 @3x для тестов экранов
void useBigPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Несколько коротких кадров: цепочка загрузок (экран → каталог → слоты) укладывается в них
Future<void> settle(WidgetTester tester, {int frames = 8, Duration step = const Duration(milliseconds: 50)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Снять дерево, чтобы таймеры экранов остановились
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}
