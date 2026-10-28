import 'dart:async';
import 'package:flutter/material.dart';
import 'social_api.dart';

/// Administrative access is validated remotely, never inferred from a nickname.
class AdminBotLauncher extends StatefulWidget {
  const AdminBotLauncher({super.key, required this.onStart, this.revision = 0});
  final Future<void> Function(String nickname) onStart;
  final int revision;
  @override
  State<AdminBotLauncher> createState() => _AdminBotLauncherState();
}

class _AdminBotLauncherState extends State<AdminBotLauncher>
    with WidgetsBindingObserver {
  String? _nickname;
  Timer? _expiry;
  int _request = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant AdminBotLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<String?> _refresh() async {
    final sequence = ++_request;
    String? name;
    DateTime? expires;
    try {
      final session = await SocialApi.instance.session();
      if (session != null && session.expiresAt.isAfter(DateTime.now())) {
        final data = await SocialApi.instance.request('/community/me');
        // Ensure logout or account switching during the request revokes access.
        final current = await SocialApi.instance.session();
        if ((data['user'] as Map?)?['role'] == 'admin' &&
            current?.token == session.token &&
            session.expiresAt.isAfter(DateTime.now())) {
          name =
              (data['user'] as Map)['nickname'] as String? ?? session.nickname;
          expires = session.expiresAt;
        }
      }
    } catch (_) {
      // No administrative shortcut when the account cannot be verified.
    }
    if (!mounted || sequence != _request) return null;
    _expiry?.cancel();
    setState(() => _nickname = name);
    if (expires != null) {
      _expiry = Timer(expires.difference(DateTime.now()), () {
        if (mounted) setState(() => _nickname = null);
      });
    }
    return name;
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final name = await _refresh();
      if (name != null && mounted) await widget.onStart(name);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_refresh());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _nickname == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            key: const ValueKey('admin-bot-launcher'),
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text(
              'Tester avec des bots · Admin',
              textAlign: TextAlign.center,
            ),
          ),
        );
}
