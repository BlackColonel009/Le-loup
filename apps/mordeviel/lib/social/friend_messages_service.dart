import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import '../audio/classic_audio.dart';
import 'social_api.dart';
import 'social_service.dart';
import 'social_notifications.dart';

class FriendMessagesService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = FriendMessagesService();
  Timer? _timer;
  Future<void>? _job;
  int? _viewer, activeFriend;
  int _epoch = 0;
  bool _foreground = true;
  final _dismissed = <int, int>{};
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _community;
  int? _communityCursor;
  int? previewId;
  AudioPlayer? _sound;
  DateTime? _lastSound;

  List<Map<String, dynamic>> get alerts => [..._items, ?_community]
      .where(
        (m) =>
            m['friend_id'] != activeFriend &&
            (m['last_id'] as int) > (_dismissed[m['friend_id']] ?? 0),
      )
      .toList();
  Map<String, dynamic>? get preview =>
      alerts.where((m) => m['last_id'] == previewId).firstOrNull;

  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    SocialService.instance.addListener(_accountChanged);
    SocialService.instance.start();
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    SocialService.instance.removeListener(_accountChanged);
    SocialService.instance.release();
    unawaited(
      _sound?.dispose().catchError((Object _) {}) ?? Future<void>.value(),
    );
    _sound = null;
  }

  void _accountChanged() {
    if (_viewer != null && SocialService.instance.nickname == null) clear();
  }

  void clear() {
    _epoch++;
    _viewer = null;
    activeFriend = null;
    _items = [];
    _community = null;
    _communityCursor = null;
    _dismissed.clear();
    previewId = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(refresh());
  }

  Future<void> refresh() => _job ??= _refresh().whenComplete(() => _job = null);
  Future<void> _refresh() async {
    final epoch = _epoch;
    try {
      final data = await SocialApi.instance.request('/social/chats/inbox');
      if (epoch != _epoch) return;
      if (_viewer != data['viewer_id']) {
        _items = [];
        _community = null;
        _communityCursor = null;
        _dismissed.clear();
        if (_viewer != null) activeFriend = null;
      }
      _viewer = data['viewer_id'] as int;
      accept(
        (data['conversations'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList(),
      );
      try {
        final community = await SocialApi.instance.request(
          _communityCursor == null
              ? '/community/messages'
              : '/community/messages?after=$_communityCursor',
        );
        if (epoch != _epoch) return;
        acceptCommunity(
          (community['messages'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList(),
        );
      } catch (_) {
        // Community availability must not interrupt private message alerts.
      }
    } on SocialError catch (error) {
      if (error.status == 401 || error.status == 403) clear();
    } catch (_) {
      // A failed social refresh must never disturb the game connection.
    }
  }

  /// Applies a server inbox snapshot without rebuilding the underlying game.
  void accept(List<Map<String, dynamic>> conversations) {
    final previous = {
      for (final item in _items) item['friend_id']: item['last_id'] as int,
    };
    _items = conversations;
    final fresh = alerts
        .where(
          (m) =>
              m['friend_id'] != -1 &&
              (m['last_id'] as int) > (previous[m['friend_id']] ?? 0),
        )
        .firstOrNull;
    if (fresh != null) {
      previewId = fresh['last_id'] as int;
      _playSound();
    } else if (preview == null) {
      previewId = null;
    }
    notifyListeners();
  }

  /// The first page is a baseline; only subsequent messages produce alerts.
  void acceptCommunity(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) {
      _communityCursor ??= 0;
      return;
    }
    messages.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    final latest = messages.last['id'] as int;
    final cursor = _communityCursor;
    if (cursor == null || latest > cursor) _communityCursor = latest;
    if (cursor == null) return;
    final fresh = messages
        .where((m) => (m['id'] as int) > cursor && m['user_id'] != _viewer)
        .toList();
    if (activeFriend == -1) {
      _community = null;
    } else if (fresh.isNotEmpty) {
      final message = fresh.last;
      final text = message['text'] as String;
      _community = {
        'friend_id': -1,
        'last_id': 1000000000000 + (message['id'] as int),
        'nickname': 'Communauté',
        'text':
            '${message['nickname']} : ${text.startsWith('[[sticker:') ? 'Sticker reçu' : text}',
        'unread_count':
            (_community?['unread_count'] as int? ?? 0) + fresh.length,
        'avatar': null,
      };
      previewId = _community!['last_id'] as int;
      _playSound();
    }
    notifyListeners();
  }

  void _playSound() {
    final settings = ClassicAudio.instance;
    if (!_foreground || settings.muted || settings.effectLevel <= 0) return;
    final now = DateTime.now();
    if (_lastSound != null && now.difference(_lastSound!).inSeconds < 2) return;
    _lastSound = now;
    unawaited(
      (_sound ??= AudioPlayer())
          .play(
            AssetSource('audio/classic/message_drop.wav'),
            volume: settings.effectLevel * .65,
          )
          .catchError((Object _) {}),
    );
  }

  void dismiss(int friendId) {
    final message = alerts.where((m) => m['friend_id'] == friendId).firstOrNull;
    if (message != null) _dismissed[friendId] = message['last_id'] as int;
    if (preview?['friend_id'] == friendId) previewId = null;
    notifyListeners();
  }

  void expirePreview(int id) {
    if (previewId != id) return;
    previewId = null;
    notifyListeners();
  }

  void reading(int friendId) {
    activeFriend = friendId;
    if (friendId == -1) {
      _community = null;
      if (preview == null) previewId = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void leave(int friendId) {
    if (activeFriend == friendId) activeFriend = null;
    unawaited(refresh());
  }

  Future<void> readThrough(int friendId, int id) async {
    final read = await SocialApi.instance.request(
      '/social/chats/$friendId/read',
      method: 'POST',
      body: {'through_id': id},
    );
    await cancelMessageNotifications(
      (read['notification_ids'] as List? ?? []).cast<int>(),
    );
    _items.removeWhere(
      (m) => m['friend_id'] == friendId && (m['last_id'] as int) <= id,
    );
    if (preview == null) previewId = null;
    notifyListeners();
  }
}
