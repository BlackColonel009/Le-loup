import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';

String get _key => 'game_notification_sound_v1:$apiBaseUrl';

Future<String> readGameNotificationSound() async {
  final value = (await SharedPreferences.getInstance()).getString(_key);
  return value == 'phone' ? 'phone' : 'game';
}

/// Keep the last selected sound available for offline/LAN games as well.
Future<void> saveGameNotificationSound(String value) async {
  if (value != 'game' && value != 'phone') return;
  await (await SharedPreferences.getInstance()).setString(_key, value);
}
