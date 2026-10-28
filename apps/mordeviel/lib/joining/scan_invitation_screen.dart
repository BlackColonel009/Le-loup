import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_host/local_host.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanInvitationScreen extends StatefulWidget {
  const ScanInvitationScreen({super.key});
  @override
  State<ScanInvitationScreen> createState() => _ScanInvitationScreenState();
}

class _ScanInvitationScreenState extends State<ScanInvitationScreen> {
  bool _accepted = false;
  String? _error, _lastRejected;
  int _attempt = 0;
  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _accept(String raw) {
    if (_accepted || !mounted) return;
    try {
      final invitation = LocalInvitation.parse(raw);
      _accepted = true;
      Navigator.pop(context, invitation);
    } on FormatException catch (error) {
      if (_lastRejected != raw) {
        setState(() {
          _lastRejected = raw;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _paste() async {
    try {
      final text = (await Clipboard.getData('text/plain'))?.text;
      if (!mounted || _accepted) return;
      if (text == null || text.trim().isEmpty) {
        setState(() => _error = 'Copie d’abord le lien partagé par le MDJ.');
      } else {
        _accept(text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Presse-papiers indisponible. Utilise la saisie manuelle.',
        );
      }
    }
  }

  Widget _camera() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: _cameraSupported
        ? MobileScanner(
            key: ValueKey(_attempt),
            // Sans contrôleur externe, le widget gère la caméra et son cycle de vie.
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.format == BarcodeFormat.qrCode &&
                    barcode.rawValue != null) {
                  _accept(barcode.rawValue!);
                  if (_accepted) return;
                }
              }
            },
            errorBuilder: (context, error) => ColoredBox(
              color: const Color(0xFF1A2730),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Autorise la caméra pour scanner le QR du MDJ. Tu peux aussi coller son lien ou saisir le salon.'
                            : 'La caméra n’est pas disponible. Tu peux coller le lien du MDJ ou saisir le salon.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _attempt++),
                        child: const Text('Réessayer la caméra'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            placeholderBuilder: (_) => const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            ),
            overlayBuilder: (context, size) => IgnorePointer(
              child: Center(
                child: Container(
                  width: size.maxWidth * .7,
                  height: size.maxHeight * .65,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFD6AE70),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          )
        : const ColoredBox(
            color: Color(0xFF1A2730),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'Le scan caméra est disponible sur téléphone. Sur cet appareil, colle le lien du salon ou utilise la saisie manuelle.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );

  Widget _help() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connecte-toi au même Wi-Fi que le MDJ et vise le QR affiché dans son salon.',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _accepted ? null : _paste,
          icon: const Icon(Icons.content_paste),
          label: const Text('Coller le lien du salon'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Utiliser la saisie manuelle'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scanner pour rejoindre')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, size) {
            if (size.maxWidth > 700) {
              return Row(
                children: [
                  Expanded(child: _camera()),
                  const SizedBox(width: 24),
                  Expanded(child: _help()),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: _camera()),
                const SizedBox(height: 16),
                SizedBox(
                  height: (size.maxHeight * .38).clamp(100, 260),
                  child: _help(),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
