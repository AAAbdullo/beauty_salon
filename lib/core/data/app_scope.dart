import 'package:flutter/widgets.dart';
import 'app_dependencies.dart';

/// Передаёт [AppDependencies] вниз по дереву виджетов: `AppScope.of(context).catalog`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  /// Зависимости с подпиской на смену набора (обычно в `build` / `didChangeDependencies`)
  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден выше по дереву. Оберните приложение (или тест) в AppScope.');
    return scope!.dependencies;
  }

  /// Зависимости без подписки (можно вызывать в `initState` и обработчиках)
  static AppDependencies read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден выше по дереву. Оберните приложение (или тест) в AppScope.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => dependencies != oldWidget.dependencies;
}
