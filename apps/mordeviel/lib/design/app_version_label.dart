import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed package, never the version advertised by the server.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});
  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<PackageInfo?> _package = _load();
  Future<PackageInfo?> _load() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo?>(
    future: _package,
    builder: (context, snapshot) {
      final info = snapshot.data;
      return Text(
        info == null ? 'Version indisponible' : 'Version ${info.version}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      );
    },
  );
}
