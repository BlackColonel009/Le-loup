import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CommunitySession {
  const CommunitySession({
    required this.token,
    required this.nickname,
    required this.expiresAt,
  });
  final String token, nickname;
  final DateTime expiresAt;
}

/// Passwords and administrator permissions are never cached.
/// The token is kept in the platform's secure storage, scoped to this API.
class CommunitySessionStore {
  CommunitySessionStore(String server, {FlutterSecureStorage? storage})
    : _key = 'community_session_v1:$server',
      _storage = storage ?? const FlutterSecureStorage();
  final String _key;
  final FlutterSecureStorage _storage;
  static final _memory = <String, CommunitySession>{};
  static Future<void>? _pending;

  Future<void> _serialize(Future<void> Function() action) {
    final previous = _pending;
    final result = previous == null ? action() : previous.then((_) => action());
    final completion = result.catchError((Object _) {});
    _pending = completion;
    unawaited(
      completion.whenComplete(() {
        if (identical(_pending, completion)) _pending = null;
      }),
    );
    return result;
  }

  Future<CommunitySession?> load({DateTime? now}) async {
    final pending = _pending;
    if (pending != null) await pending;
    CommunitySession? session = _memory[_key];
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        session = CommunitySession(
          token: data['token'] as String,
          nickname: data['nickname'] as String,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            data['expires_at'] as int,
          ),
        );
      }
    } catch (_) {
      // Continue in memory if platform storage is temporarily unavailable.
    }
    if (session == null) return null;
    final current = now ?? DateTime.now();
    if (session.token.isEmpty ||
        !session.expiresAt.isAfter(current) ||
        session.expiresAt.difference(current) > const Duration(days: 1)) {
      await clear();
      return null;
    }
    _memory[_key] = session;
    return session;
  }

  Future<void> save(CommunitySession session) => _serialize(() async {
    _memory[_key] = session;
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'token': session.token,
          'nickname': session.nickname,
          'expires_at': session.expiresAt.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // No fallback to unencrypted preferences.
    }
  });

  Future<void> clear() => _serialize(() async {
    _memory.remove(_key);
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  });
}
