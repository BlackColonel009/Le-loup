import 'package:shared_preferences/shared_preferences.dart';
import 'public_content.dart';

const maintenanceMessage = 'On est en petite maintenance, s’il vous plaît.';

Future<Map<String, dynamic>> readMaintenance({Future<Map<String,dynamic>> Function()? fetch}) async {
  Map<String, dynamic>? fresh;
  try {
    fresh = await (fetch?.call() ?? loadPublicContent('status')).timeout(const Duration(seconds: 2));
  } catch (_) {}
  final cached = <String, dynamic>{
    'local_enabled': true,
    'online_enabled': true,
    'message': maintenanceMessage,
  };
  try {
    final preferences = await SharedPreferences.getInstance();
    for (final key in ['local_enabled', 'online_enabled']) {
      cached[key] = preferences.getBool('maintenance.$key') ?? true;
      if (fresh?[key] is bool) {
        await preferences.setBool('maintenance.$key', fresh![key] as bool);
      }
    }
    cached['message'] =
        preferences.getString('maintenance.message') ?? maintenanceMessage;
    if (fresh?['message'] is String) {
      await preferences.setString(
        'maintenance.message',
        fresh!['message'] as String,
      );
    }
  } catch (_) {}
  return fresh ?? cached;
}
