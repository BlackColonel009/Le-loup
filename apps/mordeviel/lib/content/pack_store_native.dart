import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/server_config.dart';

class PackStore extends ChangeNotifier {
  PackStore({Directory? directory, Uri? base})
    : _root = directory,
      _customBase = base;
  static final instance = PackStore();
  Directory? _root;
  final Uri? _customBase;
  final List<Map<String, dynamic>> packs = [];
  final Map<String, String> _paths = {};
  final Map<String, Future<void>> _jobs = {};
  final Set<String> _cancelled = {};
  final Map<String, int> _cancelEpoch = {};
  final Map<String, double> progress = {};
  String? error;
  Future<void>? _init, _refresh;
  Future<void> _saving = Future.value();
  String? pathFor(String asset) => _paths[asset];
  bool installed(String id) => packs.any(
    (p) =>
        p['id'] == id &&
        (p['files'] as List).every(
          (f) => _paths[f['asset']] == _file(p, f as Map).path,
        ),
  );
  Uri get _base => _customBase ?? Uri.parse(apiBaseUrl);
  Future<void> initialize() => _init ??= _initialize();
  Future<void> _initialize() async {
    _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/content-packs',
    );
    await _root!.create(recursive: true);
    final index = File('${_root!.path}/installed.json');
    if (await index.exists()) {
      try {
        final saved = jsonDecode(await index.readAsString()) as Map;
        for (final e in saved.entries) {
          if (e.key is! String ||
              e.value is! String ||
              !RegExp(
                r'^[a-z0-9-]{1,60}/[a-f0-9]{16}/[a-f0-9]{64}$',
              ).hasMatch(e.value as String)) {
            continue;
          }
          final file = File('${_root!.path}/${e.value}');
          if (await file.exists()) _paths[e.key as String] = file.path;
        }
      } catch (_) {
        /* Recover using the cached catalogue. */
      }
    }
    final cached = File('${_root!.path}/catalog.json');
    if (await cached.exists()) {
      try {
        _accept(jsonDecode(await cached.readAsString()));
        await _index();
      } catch (_) {
        packs.clear();
      }
    }
  }

  void _accept(dynamic data) {
    final incoming = (data as Map)['packs'] as List;
    if (incoming.length > 64) {
      throw const FormatException('Catalogue trop volumineux.');
    }
    final ids = <String>{}, assets = <String>{};
    for (final raw in incoming) {
      final p = raw as Map;
      if (!RegExp(r'^[a-z0-9-]{1,60}$').hasMatch(p['id'] as String) ||
          !ids.add(p['id'] as String) ||
          !RegExp(r'^[a-f0-9]{16}$').hasMatch(p['version'] as String)) {
        throw const FormatException('Pack invalide.');
      }
      if ((p['files'] as List).length > 300) {
        throw const FormatException('Pack trop volumineux.');
      }
      for (final rawFile in p['files'] as List) {
        final f = rawFile as Map, asset = f['asset'] as String;
        if (!RegExp(r'^assets/[a-zA-Z0-9_./-]+$').hasMatch(asset) ||
            asset.split('/').contains('..') ||
            !assets.add(asset) ||
            (f['size'] as num) <= 0 ||
            (f['size'] as num) > 64 * 1048576 ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(f['sha256'] as String) ||
            f['url'] !=
                '/content/packs/${p['id']}/${p['version']}/${f['sha256']}') {
          throw const FormatException('Fichier de pack invalide.');
        }
      }
    }
    packs
      ..clear()
      ..addAll(incoming.map((p) => Map<String, dynamic>.from(p as Map)));
  }

  Future<void> _index() async {
    final missing = <String>[];
    for (final e in _paths.entries) {
      if (!await File(e.value).exists()) missing.add(e.key);
    }
    for (final asset in missing) {
      _paths.remove(asset);
    }
    for (final p in packs) {
      for (final f in p['files'] as List) {
        final file = _file(p, f as Map);
        if (await file.exists() && await file.length() == f['size']) {
          _paths[f['asset'] as String] = file.path;
        }
      }
    }
  }

  File _file(Map p, Map f) =>
      File('${_root!.path}/${p['id']}/${p['version']}/${f['sha256']}');
  Future<void> _saveIndex() =>
      _saving = _saving.catchError((Object _) {}).then((_) async {
        final saved = {
          for (final e in _paths.entries)
            e.key: e.value
                .substring(_root!.path.length + 1)
                .replaceAll('\\', '/'),
        };
        final temp = File('${_root!.path}/installed.tmp');
        await temp.writeAsString(jsonEncode(saved), flush: true);
        final target = File('${_root!.path}/installed.json');
        if (await target.exists()) await target.delete();
        await temp.rename(target.path);
      });
  Future<void> refresh() =>
      _refresh ??= _fetch().whenComplete(() => _refresh = null);
  Future<void> _fetch() async {
    await initialize();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(_base.resolve('/content/packs'))
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw const HttpException('Catalogue indisponible.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1048576) {
          throw const FormatException('Catalogue trop volumineux.');
        }
      }
      final data = jsonDecode(utf8.decode(bytes));
      _accept(data);
      final temp = File('${_root!.path}/catalog.tmp');
      await temp.writeAsString(jsonEncode(data), flush: true);
      final target = File('${_root!.path}/catalog.json');
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
      await _index();
      error = null;
    } catch (_) {
      error =
          'Catalogue inaccessible. Les packs déjà téléchargés restent disponibles.';
      rethrow;
    } finally {
      client.close(force: true);
      notifyListeners();
    }
  }

  Future<void> ensureAsset(String asset) async {
    await initialize();
    if (_paths.containsKey(asset)) return;
    if (packs.isEmpty) await refresh();
    final p = packs
        .where((p) => (p['files'] as List).any((f) => f['asset'] == asset))
        .firstOrNull;
    if (p == null) return;
    await _download(p, only: asset);
  }

  Future<void> install(String id) async {
    await initialize();
    final p = packs.firstWhere((p) => p['id'] == id);
    await _download(p);
  }

  Future<void> _download(Map<String, dynamic> p, {String? only}) async {
    final id = p['id'] as String;
    final previous = _jobs[id] ?? Future<void>.value();
    final epoch = _cancelEpoch[id] ?? 0;
    final job = previous.catchError((Object _) {}).then((_) async {
      if ((_cancelEpoch[id] ?? 0) != epoch) {
        throw StateError('Téléchargement suspendu.');
      }
      if (only != null && _paths.containsKey(only) ||
          only == null && installed(id)) {
        return;
      }
      _cancelled.remove(id);
      await _perform(p, only: only);
    });
    _jobs[id] = job;
    try {
      await job;
    } finally {
      if (identical(_jobs[id], job)) {
        _jobs.remove(id);
        progress.remove(id);
      }
      notifyListeners();
    }
  }

  Future<void> _perform(Map<String, dynamic> p, {String? only}) async {
    final id = p['id'] as String;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final files = (p['files'] as List)
        .where((f) => only == null || f['asset'] == only)
        .toList();
    final total = files.fold<int>(0, (n, f) => n + (f['size'] as int));
    var done = 0;
    try {
      for (final raw in files) {
        if (_cancelled.contains(id)) {
          throw StateError('Téléchargement suspendu.');
        }
        final f = raw as Map, file = _file(p, f), expected = f['size'] as int;
        if (_paths[f['asset']] == file.path) {
          done += expected;
          continue;
        }
        await file.parent.create(recursive: true);
        final part = File('${file.path}.part');
        var offset = await part.exists() ? await part.length() : 0;
        if (offset > expected) {
          await part.delete();
          offset = 0;
        }
        if (offset < expected) {
          final request = await client
              .getUrl(_base.resolve(f['url'] as String))
              .timeout(const Duration(seconds: 15));
          request.followRedirects = false;
          if (offset > 0) request.headers.set('Range', 'bytes=$offset-');
          final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
          if (response.statusCode != 200 && response.statusCode != 206) {
            throw const HttpException('Téléchargement indisponible.');
          }
          if (response.statusCode == 206 &&
              !response.headers
                  .value('content-range')
                  .toString()
                  .startsWith('bytes $offset-')) {
            throw const HttpException('Reprise invalide.');
          }
          if (response.statusCode == 200) offset = 0;
          final sink = part.openWrite(
            mode: offset > 0 ? FileMode.append : FileMode.write,
          );
          try {
            await for (final chunk in response.timeout(
              const Duration(seconds: 20),
            )) {
              if (_cancelled.contains(id)) {
                throw StateError('Téléchargement suspendu.');
              }
              offset += chunk.length;
              if (offset > expected) {
                throw const FormatException('Taille de fichier incorrecte.');
              }
              sink.add(chunk);
              progress[id] = (done + offset) / total;
              notifyListeners();
            }
          } finally {
            await sink.close();
          }
        }
        if (await part.length() != expected ||
            (await sha256.bind(part.openRead()).first).toString() !=
                f['sha256']) {
          await part.delete();
          throw const FormatException(
            'Fichier incomplet ou corrompu. Réessaie.',
          );
        }
        if (await file.exists()) await file.delete();
        await part.rename(file.path);
        _paths[f['asset'] as String] = file.path;
        await _saveIndex();
        done += expected;
        notifyListeners();
      }
      error = null;
    } catch (_) {
      error = 'Téléchargement interrompu. Tu peux le reprendre.';
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void cancel(String id) {
    _cancelled.add(id);
    _cancelEpoch[id] = (_cancelEpoch[id] ?? 0) + 1;
  }

  Future<void> remove(String id) async {
    if (!RegExp(r'^[a-z0-9-]{1,60}$').hasMatch(id)) return;
    cancel(id);
    try {
      await _jobs[id];
    } catch (_) {
      /* Wait for the writer before deletion. */
    }
    final dir = Directory('${_root!.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    _paths.removeWhere(
      (_, path) =>
          path.startsWith('${dir.path}/') || path.startsWith('${dir.path}\\'),
    );
    await _saveIndex();
    await _index();
    notifyListeners();
  }
}
