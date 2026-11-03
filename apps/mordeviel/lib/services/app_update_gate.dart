import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cards/card_gallery.dart';
import 'app_updates.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.check,
    this.launch,
  });
  final Widget child;
  final Future<AppRelease?> Function()? check;
  final Future<bool> Function(Uri)? launch;
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  AppRelease? _release;
  bool _checking = true, _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _release != null) _check();
  }

  Future<void> _check() async {
    if (_checking && _release != null) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await (widget.check?.call() ?? checkAppUpdate());
      if (mounted) setState(() => _release = result);
    } catch (_) {
      // A first check failing offline must not break local play. A known update
      // stays mandatory until a successful check confirms an installed release.
      if (mounted && _release != null) {
        setState(
          () => _error =
              'Vérification indisponible. Réessaie avec une connexion Internet.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    if (_opening || _release == null) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final url = _release!.url;
      final opened =
          await (widget.launch?.call(url) ??
              launchUrl(url, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('unavailable');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Impossible d’ouvrir le téléchargement. Réessaie ou copie le lien ci-dessous.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && _release == null) return widget.child;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: TavernBackground(
          dim: .93,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 490),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.system_update_alt_rounded,
                            color: Color(0xFFE5C385),
                            size: 52,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _release == null
                                ? 'Préparation du village…'
                                : 'Mise à jour disponible',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          if (_release != null) ...[
                            Text(
                              'Version ${_release!.version}',
                              style: const TextStyle(
                                color: Color(0xFFE5C385),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Une nouvelle version de Mordeviel vous attend. Installez la mise à jour avant de continuer votre aventure.',
                              textAlign: TextAlign.center,
                              style: TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _opening || _checking
                                    ? null
                                    : _download,
                                icon: const Icon(Icons.download_rounded),
                                label: Text(
                                  _opening
                                      ? 'Ouverture du téléchargement…'
                                      : 'Télécharger la mise à jour',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _checking || _opening ? null : _check,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Vérifier à nouveau'),
                            ),
                          ],
                          if (_checking)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: LinearProgressIndicator(),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            if (_release != null)
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: _release!.url.toString(),
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lien de téléchargement copié.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text(
                                  'Copier le lien de téléchargement',
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
