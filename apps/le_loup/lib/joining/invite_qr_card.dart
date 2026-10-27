import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_host/local_host.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteQrCard extends StatefulWidget {
  const InviteQrCard({super.key, required this.addresses, required this.code});
  final List<String> addresses;
  final String code;
  @override
  State<InviteQrCard> createState() => _InviteQrCardState();
}

class _InviteQrCardState extends State<InviteQrCard> {
  String? _selected;
  List<String> get _addresses {
    final valid = <String>{};
    for (final address in widget.addresses) {
      try {
        valid.add(LocalInvitation(address: address, code: widget.code).address);
      } on FormatException {
        /* Interface non utilisable pour un QR IPv4. */
      }
    }
    int rank(String value) => value.startsWith('192.168.')
        ? 0
        : value.startsWith('10.')
        ? 1
        : value.startsWith('172.')
        ? 2
        : 3;
    return valid.toList()..sort((a, b) {
      final result = rank(a).compareTo(rank(b));
      return result != 0 ? result : a.compareTo(b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _addresses;
    if (addresses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Connecte le MDJ au Wi-Fi pour afficher le QR code du salon.',
          ),
        ),
      );
    }
    final selected = addresses.contains(_selected)
        ? _selected!
        : addresses.first;
    final invitation = LocalInvitation(address: selected, code: widget.code);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inviter par QR code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Même Wi-Fi, puis dans Le Loup : « Scanner pour rejoindre ».',
            ),
            const SizedBox(height: 16),
            if (addresses.length > 1)
              DropdownButtonFormField<String>(
                key: ValueKey(addresses.join('|')),
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Adresse Wi-Fi du MDJ',
                ),
                isExpanded: true,
                items: [
                  for (final address in addresses)
                    DropdownMenuItem(value: address, child: Text(address)),
                ],
                onChanged: (value) => setState(() => _selected = value),
              ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, size) => Center(
                child: QrImageView(
                  key: ValueKey(invitation.payload),
                  data: invitation.payload,
                  size: math.min(size.maxWidth, 270),
                  padding: const EdgeInsets.all(18),
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  semanticsLabel:
                      'QR code pour rejoindre le salon ${widget.code}',
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Salon ${widget.code}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SelectableText(selected, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copier le lien du salon'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: invitation.payload),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien du salon copié.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
