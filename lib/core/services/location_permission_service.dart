import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LocationPermissionStatus {
  /// Доступ разрешён
  granted,

  /// Пользователь отказал (разрешить можно только в настройках телефона)
  denied,

  /// Ещё не спрашивали
  notDetermined,

  /// Запрещено политикой устройства
  restricted,

  /// Платформа не поддерживает запрос (десктоп, веб, тесты)
  unsupported,
}

/// Разрешение на геолокацию. Запрашивается, когда оно действительно нужно (при открытии карты и только
/// если включена настройка «Показывать салоны рядом со мной»), а не при запуске приложения.
/// Нативная часть — канал `com.beauty_salon/location` в AppDelegate.swift и MainActivity.kt.
class LocationPermissionService {
  LocationPermissionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.beauty_salon/location');

  final MethodChannel _channel;

  static LocationPermissionStatus _parse(Object? value) => switch (value) {
    'granted' => LocationPermissionStatus.granted,
    'denied' => LocationPermissionStatus.denied,
    'notDetermined' => LocationPermissionStatus.notDetermined,
    'restricted' => LocationPermissionStatus.restricted,
    _ => LocationPermissionStatus.unsupported,
  };

  /// Текущее состояние разрешения, без показа системного окна
  Future<LocationPermissionStatus> status() async {
    try {
      return _parse(await _channel.invokeMethod<String>('status'));
    } on MissingPluginException {
      return LocationPermissionStatus.unsupported;
    } on PlatformException catch (e) {
      debugPrint('[LocationPermission] status error: $e');
      return LocationPermissionStatus.denied;
    }
  }

  /// Показать системное окно запроса, если пользователя ещё не спрашивали; вернуть итоговое состояние
  Future<LocationPermissionStatus> request() async {
    try {
      return _parse(await _channel.invokeMethod<String>('request'));
    } on MissingPluginException {
      return LocationPermissionStatus.unsupported;
    } on PlatformException catch (e) {
      debugPrint('[LocationPermission] request error: $e');
      return LocationPermissionStatus.denied;
    }
  }
}
