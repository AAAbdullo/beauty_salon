import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Сервис голосовых подсказок для 3D-навигатора
class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  static const MethodChannel _channel = MethodChannel('com.beauty_salon/tts');

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  set isMuted(bool val) {
    _isMuted = val;
    if (_isMuted) {
      stop();
    }
  }

  void toggleMute() {
    isMuted = !_isMuted;
  }

  /// Воспроизведение фразы через нативный TTS синтезатор речи
  Future<void> speak(String text) async {
    if (_isMuted) return;
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      debugPrint('[VoiceGuidance] TTS not available or error: $e');
    }
  }

  /// Немедленная остановка речи
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
