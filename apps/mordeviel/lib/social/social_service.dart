import 'dart:async';
import 'package:flutter/widgets.dart';
import 'social_api.dart';
import 'social_notifications.dart';
import '../services/game_notification_sound.dart';

class SocialService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = SocialService();
  Timer? _timer;
  bool _busy = false, _active = true;
  int _listeners = 0;
  int _epoch = 0;
  Future<void>? _phoneSync;
  Future<void> _presenceWrite = Future.value();
  final _announcements = <String>[];
  final _presenceAlertIds = <int>{};
  String? _deviceId;
  bool signedIn = false;
  int friendRequests = 0, invitations = 0;
  int? userId;
  bool get hasNews => friendRequests + invitations > 0;
  String? takePresenceAnnouncement() {
    if (!_active || _announcements.isEmpty) return null;
    final names = _announcements.take(3).toList();
    final more = _announcements.length - names.length;
    _announcements.clear();
    return '${names.join(', ')} ${names.length == 1 ? 's’est connecté' : 'se sont connectés'} à Mordeviel.${more > 0 ? ' Et $more autre(s) ami(s).' : ''}';
  }

  Future<void> _presence(String state) {
    final epoch = _epoch;
    return _presenceWrite = _presenceWrite.then((_) async {
      if (epoch != _epoch || (state == 'online' && !_active)) return;
      try {
        _deviceId ??= await socialDeviceId();
        await SocialApi.instance.request(
          '/social/presence',
          method: 'POST',
          body: {'device_id': _deviceId, 'state': state},
        );
      } catch (_) {
        // A lost connection is handled by the server lease expiry.
      }
    });
  }

  Future<void> _presenceAlerts(int epoch) async {
    try {
      _deviceId ??= await socialDeviceId();
      final data = await SocialApi.instance.request(
        '/social/presence/alerts?device_id=$_deviceId',
      );
      if (epoch != _epoch || !_active) return;
      for (final alert in (data['alerts'] as List? ?? []).whereType<Map>()) {
        if (_presenceAlertIds.add(alert['id'] as int)) {
          _announcements.add(alert['nickname'] as String);
          if (_presenceAlertIds.length > 300) {
            _presenceAlertIds.remove(_presenceAlertIds.first);
          }
        }
        await SocialApi.instance.request(
          '/social/presence/alerts/${alert['id']}/delivered',
          method: 'POST',
          body: {'device_id': _deviceId},
        );
        if (epoch != _epoch) return;
      }
    } catch (_) {
      // Presence never prevents access to the game or community.
    }
  }

  void start() {
    _listeners++;
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_active) unawaited(refresh());
    });
  }

  void release() {
    _listeners--;
    if (_listeners <= 0) {
      _listeners = 0;
      _timer?.cancel();
      _timer = null;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      unawaited(refresh());
    } else if (signedIn) {
      unawaited(
        _presence(state == AppLifecycleState.detached ? 'offline' : 'away'),
      );
    }
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final epoch = _epoch;
    try {
      final data = await SocialApi.instance.request('/social/summary');
      if (epoch != _epoch) return;
      if (userId != data['user_id']) {
        _announcements.clear();
        _presenceAlertIds.clear();
      }
      signedIn = true;
      userId = data['user_id'] as int;
      friendRequests = data['friend_requests'] as int;
      invitations = data['invitations'] as int;
      final sound = data['game_notification_sound'];
      if (sound is String) {
        try {
          await saveGameNotificationSound(sound);
        } catch (_) {}
      }
      if (_active) {
        await _presence('online');
        await _presenceAlerts(epoch);
        if (epoch != _epoch) return;
      }
      try {
        final sync = () async {
          await syncPhoneAccount(userId!, data['phone_notifications'] == true);
          await fetchPhoneNotifications();
        }();
        _phoneSync = sync;
        try {
          await sync;
        } finally {
          if (identical(_phoneSync, sync)) _phoneSync = null;
        }
      } catch (_) {
        /* Badges remain available without Android permission. */
      }
    } on SocialError catch (error) {
      if (error.status == 401 || error.status == 403) {
        _announcements.clear();
        _presenceAlertIds.clear();
        signedIn = false;
        userId = null;
        friendRequests = 0;
        invitations = 0;
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _epoch++;
    _announcements.clear();
    _presenceAlertIds.clear();
    // Finish pending heartbeats before marking this device offline.
    final offline = _presence('offline');
    signedIn = false;
    userId = null;
    friendRequests = 0;
    invitations = 0;
    notifyListeners();
    try {
      await offline;
      await _phoneSync;
    } catch (_) {
      /* Revoke only after an in-flight registration finishes. */
    }
    try {
      await disablePhoneNotifications();
    } catch (_) {
      /* Logging out must not depend on a notification plugin. */
    }
  }
}
