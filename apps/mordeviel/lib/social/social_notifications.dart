import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'social_api.dart';
import '../services/server_config.dart';
import '../services/game_notification_sound.dart';

const _workerName = 'mordeviel-social-notifications';
final _notifications = FlutterLocalNotificationsPlugin();
const _secure = FlutterSecureStorage();
String get _deviceTokenKey => 'social_background_v1:$apiBaseUrl';
String get _deviceExpiryKey => 'social_background_expiry_v1:$apiBaseUrl';
String get _deviceUserKey => 'social_background_user_v1:$apiBaseUrl';
final pendingSocialNotification = ValueNotifier<String?>(null);
bool _launchRead = false;
bool _workerStarted = false;

/// Separate from social opt-in: local/LAN players need no community account.
Future<bool> prepareGameNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  await _initializeNotifications();
  return await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
}

Future<void> showGameStartedNotification(String code) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _initializeNotifications();
  final sound = await readGameNotificationSound();
  await _notifications.show(
    id: 940002,
    title: 'Le MDJ a lancé la partie !',
    body: 'Le village t’attend… La partie commence. Reviens dans Mordeviel.',
    notificationDetails: NotificationDetails(
      android: gameStartSoundDetails(sound),
    ),
    payload: 'game-start:$code',
  );
}

/// Distinct channels keep Android from retaining the previous sound choice.
AndroidNotificationDetails gameStartSoundDetails(String sound) =>
    sound == 'phone'
    ? const AndroidNotificationDetails(
        'mordeviel_game_start_phone_v1',
        'Début de partie · Son du téléphone',
        channelDescription:
            'Alerte de lancement avec la sonnerie standard du téléphone',
        icon: 'ic_social_wolf',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        category: AndroidNotificationCategory.event,
      )
    : const AndroidNotificationDetails(
        'mordeviel_game_start_v2',
        'Début de partie · Son Mordeviel',
        channelDescription: 'Alerte sonore lorsque le MDJ distribue les cartes',
        icon: 'ic_social_wolf',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('mordeviel_game_start'),
        enableVibration: true,
        autoCancel: true,
        category: AndroidNotificationCategory.event,
      );

Future<void> cancelGameStartedNotification() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _notifications.cancel(id: 940002);
  } catch (_) {}
}

Future<void> _cancelSocialNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  for (final id in prefs.getStringList('social_shown_ids') ?? <String>[]) {
    final number = int.tryParse(id);
    if (number != null) await _notifications.cancel(id: number);
  }
}

@pragma('vm:entry-point')
void socialNotificationDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await fetchPhoneNotifications();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<String> socialDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('social_device_id');
  if (id == null) {
    final random = Random.secure();
    id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('social_device_id', id);
  }
  return id;
}

Future<void> _initializeNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_social_wolf'),
    ),
    onDidReceiveNotificationResponse: (response) =>
        pendingSocialNotification.value = response.payload ?? 'invitation',
  );
}

Future<void> initializeSocialNotificationUi() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _initializeNotifications();
    if (!_launchRead) {
      _launchRead = true;
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        pendingSocialNotification.value =
            details?.notificationResponse?.payload ?? 'invitation';
      }
    }
  } catch (_) {
    /* Notifications are optional. */
  }
}

Future<void> syncPhoneAccount(int userId, bool enabled) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final previous = await _secure.read(key: _deviceUserKey);
  if (previous != null && previous != '$userId') {
    await disablePhoneNotifications();
  }
  if (enabled) {
    await _initializeNotifications();
    final allowed =
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
    if (allowed) {
      await registerSocialDevice(userId: userId);
      await _scheduleNotifications();
    }
  }
}

Future<bool> enablePhoneNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  await _initializeNotifications();
  final allowed =
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
  if (!allowed) return false;
  await registerSocialDevice(force: true);
  await _scheduleNotifications();
  return true;
}

Future<void> _scheduleNotifications() async {
  if (_workerStarted) return;
  await Workmanager().initialize(socialNotificationDispatcher);
  await Workmanager().registerPeriodicTask(
    _workerName,
    _workerName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  _workerStarted = true;
}

Future<void> registerSocialDevice({bool force = false, int? userId}) async {
  final expiry =
      double.tryParse(await _secure.read(key: _deviceExpiryKey) ?? '') ?? 0;
  if (!force && expiry > DateTime.now().millisecondsSinceEpoch / 1000 + 86400) {
    return;
  }
  final data = await SocialApi.instance.request(
    '/social/devices',
    method: 'POST',
    body: {'device_id': await socialDeviceId()},
  );
  await _secure.write(
    key: _deviceTokenKey,
    value: data['background_token'] as String,
  );
  await _secure.write(key: _deviceExpiryKey, value: '${data['expires_at']}');
  await _secure.write(key: _deviceUserKey, value: '${data['user_id']}');
}

Future<void> disablePhoneNotifications({bool revoke = true}) async {
  _workerStarted = false;
  if (revoke && await _secure.read(key: _deviceTokenKey) != null) {
    try {
      final token = await _secure.read(key: _deviceTokenKey);
      if (token != null) {
        await SocialApi.instance.request(
          '/social/device',
          method: 'DELETE',
          deviceToken: token,
        );
      }
      await SocialApi.instance.request(
        '/social/devices/${await socialDeviceId()}',
        method: 'DELETE',
      );
    } catch (_) {}
  }
  await _secure.delete(key: _deviceTokenKey);
  await _secure.delete(key: _deviceExpiryKey);
  await _secure.delete(key: _deviceUserKey);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Workmanager().cancelByUniqueName(_workerName);
      await _cancelSocialNotifications();
    } catch (_) {
      /* Plugin may not have been initialized. */
    }
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('social_shown_ids');
}

Future<void> fetchPhoneNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final token = await _secure.read(key: _deviceTokenKey);
  if (token == null) return;
  Map<String, dynamic> data;
  try {
    data = await SocialApi.instance.request(
      '/social/device/notifications',
      deviceToken: token,
    );
  } on SocialError catch (error) {
    if (error.status == 401) {
      await _secure.delete(key: _deviceTokenKey);
      await _secure.delete(key: _deviceExpiryKey);
      return;
    }
    rethrow;
  }
  await _initializeNotifications();
  final prefs = await SharedPreferences.getInstance();
  final shown = (prefs.getStringList('social_shown_ids') ?? []).toSet();
  for (final id in data['cancelled_ids'] as List) {
    await _notifications.cancel(id: id as int);
    shown.remove('$id');
  }
  if (data['enabled'] != true) {
    await _cancelSocialNotifications();
    return;
  }
  for (final raw in data['notifications'] as List) {
    if (await _secure.read(key: _deviceTokenKey) != token) return;
    final n = raw as Map;
    if (!shown.contains('${n['id']}')) {
      await _notifications.show(
        id: n['id'] as int,
        title: n['title'] as String,
        body: n['body'] as String,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mordeviel_social',
            'Invitations et amis',
            channelDescription:
                'Invitations, demandes d’amitié et connexions des amis',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_social_wolf',
            autoCancel: true,
          ),
        ),
        payload: n['kind'] as String,
      );
      shown.add('${n['id']}');
      await prefs.setStringList('social_shown_ids', shown.toList());
    }
    await SocialApi.instance.request(
      '/social/device/notifications/${n['id']}/delivered',
      method: 'POST',
      deviceToken: token,
    );
  }
}
