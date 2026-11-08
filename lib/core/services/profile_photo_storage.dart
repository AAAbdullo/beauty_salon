import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальное хранение фото профиля: выбранный файл копируется в папку приложения (исходник может исчезнуть
/// из галереи или кэша пикера), путь запоминается между запусками. Сбой хранилища не должен ронять приложение.
/// [BACKEND NOTE]: с бэкендом фото загружается на сервер (POST /api/v1/me/avatar), а здесь остаётся только кэш.
class ProfilePhotoStorage {
  ProfilePhotoStorage._();

  static const _key = 'client_avatar_path';

  /// Копирует [sourcePath] в папку приложения под новым именем (новое имя — чтобы Flutter не показывал
  /// старую картинку из кэша), запоминает путь и удаляет прежнее фото. Возвращает новый путь.
  static Future<String> save(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = '${dir.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(target);

    final previous = await restore();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, target);
    } catch (_) {}
    if (previous != null && previous != target) await _delete(previous);
    return target;
  }

  /// Сохранённое фото, если файл ещё на месте
  static Future<String?> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_key);
      if (path != null && await File(path).exists()) return path;
    } catch (_) {}
    return null;
  }

  /// Удаляет сохранённое фото и запись о нём
  static Future<void> clear() async {
    final previous = await restore();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
    if (previous != null) await _delete(previous);
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
