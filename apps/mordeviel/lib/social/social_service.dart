import 'dart:async';
import 'package:flutter/widgets.dart';
import 'social_api.dart';
import 'social_notifications.dart';

class SocialService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = SocialService();
  Timer? _timer;
  bool _busy = false, _active = true;
  int _listeners = 0;
  int _epoch = 0;
  Future<void>? _phoneSync;
  bool signedIn = false;
  int friendRequests = 0, invitations = 0;
  int? userId;
  bool get hasNews => friendRequests + invitations > 0;
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
    if (_active) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final epoch = _epoch;
    try {
      final data = await SocialApi.instance.request('/social/summary');
      if (epoch != _epoch) return;
      signedIn = true;
      userId = data['user_id'] as int;
      friendRequests = data['friend_requests'] as int;
      invitations = data['invitations'] as int;
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
    signedIn = false;
    userId = null;
    friendRequests = 0;
    invitations = 0;
    notifyListeners();
    try {
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
