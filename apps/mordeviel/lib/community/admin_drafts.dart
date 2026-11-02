import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Private local drafts, scoped to the server and administrator account.
class AdminDrafts {
  AdminDrafts(this.scope);
  final String scope;
  static const _storage = FlutterSecureStorage();
  static final _memory = <String, Map<String, dynamic>>{};
  static final _pending = <String, Future<bool>>{};
  String _key(String slot) =>
      'mordeviel.admin.draft.${Uri.encodeComponent(scope)}.$slot';

  Future<Map<String, dynamic>?> read(String slot) async {
    final key = _key(slot);
    final pending = _pending[key];
    if (pending != null) await pending;
    if (_memory.containsKey(key)) return Map.of(_memory[key]!);
    try {
      final raw = await _storage.read(key: key);
      if (raw != null) {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _memory[key] = data;
        return Map.of(data);
      }
    } catch (_) {
      // Storage failure must not publish content or close the editor.
    }
    return null;
  }

  Future<bool> save(String slot, Map<String, dynamic> data) {
    final key = _key(slot);
    _memory[key] = Map.of(data);
    final encoded = jsonEncode(data);
    return _serialize(key, () => _storage.write(key: key, value: encoded));
  }

  Future<bool> clear(String slot) {
    final key = _key(slot);
    _memory.remove(key);
    return _serialize(key, () => _storage.delete(key: key));
  }

  Future<bool> _serialize(String key, Future<void> Function() action) {
    final previous = _pending[key] ?? Future.value(true);
    final next = previous.then((_) async {
      try {
        await action();
        return true;
      } catch (_) {
        return false;
      }
    });
    _pending[key] = next;
    return next;
  }
}
