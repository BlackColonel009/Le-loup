import 'package:flutter/foundation.dart';

class PackStore extends ChangeNotifier {
  static final instance = PackStore();
  final List<Map<String, dynamic>> packs = [];
  final Map<String, double> progress = {};
  String? error =
      'Les packs téléchargeables sont disponibles dans l’application native.';
  String? pathFor(String asset) => null;
  bool installed(String id) => false;
  Future<void> initialize() async {}
  Future<void> refresh() async {}
  Future<void> ensureAsset(String asset) async {}
  Future<void> install(String id) async {}
  Future<void> remove(String id) async {}
  void cancel(String id) {}
}
