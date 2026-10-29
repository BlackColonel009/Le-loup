import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../social/social_notifications.dart';

class GameBackgroundSession {
  static const _channel = MethodChannel('mordeviel/game_session');
  static int _generation = 0;
  static Future<bool> start(String code) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final generation = ++_generation;
      final allowed = await prepareGameNotifications();
      if (generation != _generation) return allowed;
      await _channel.invokeMethod<bool>('start', {'code': code});
      if (generation != _generation) await stop();
      return allowed;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    _generation++;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}

/// A resumed snapshot must not ring again, or ring on initial entry mid-game.
class GameStartAlertTracker {
  String? _phase;
  bool _announced = false;
  bool update(String? phase, {required bool background}) {
    final started = _phase == 'lobby' && phase != null && phase != 'lobby';
    _phase = phase;
    if (!started || _announced) return false;
    _announced = true;
    return background;
  }

  void reset() {
    _phase = null;
    _announced = false;
  }
}
