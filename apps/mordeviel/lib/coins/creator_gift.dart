import 'package:flutter/material.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import 'coin_widgets.dart';

bool _showingGift = false;
final _seenByAccount = <int>{};

Future<void> showCreatorGift(BuildContext context) async {
  if (_showingGift || ModalRoute.of(context)?.isCurrent != true) return;
  _showingGift = true;
  try {
    final gift = await SocialApi.instance.request('/coins/gifts/creator');
    if (gift['claimed'] == true ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_seenByAccount.add(gift['user_id'] as int)) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreatorGiftDialog(gift: gift),
    );
  } catch (_) {
    // This optional gift can always be recovered from the wallet after reconnecting.
  } finally {
    _showingGift = false;
  }
}

class CreatorGiftDialog extends StatefulWidget {
  const CreatorGiftDialog({super.key, required this.gift});
  final Map<String, dynamic> gift;
  @override
  State<CreatorGiftDialog> createState() => _CreatorGiftDialogState();
}

class _CreatorGiftDialogState extends State<CreatorGiftDialog> {
  bool _busy = false, _claimed = false;
  String? _error;
  Future<void> _claim() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await SocialApi.instance.request(
        '/coins/gifts/creator/claim',
        method: 'POST',
      );
      SocialService.instance.updateCoinBalance(
        result['balance'] as int,
        forUser: result['user_id'] as int,
      );
      if (mounted) setState(() => _claimed = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SocialError
              ? error.message
              : 'Ton cadeau est conservé. Réessaie quand la connexion sera rétablie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        _claimed ? '100 lunes dans ta bourse !' : 'Un cadeau du Créateur',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard, color: coinGold, size: 48),
          const SizedBox(height: 14),
          const CoinToken(size: 90),
          const SizedBox(height: 14),
          const Text(
            '+100 Lunes d’or',
            style: TextStyle(
              fontSize: 24,
              color: coinGold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _claimed
                ? 'Merci de faire vivre le village. Bonne aventure !\n— Logan R.D'
                : widget.gift['message'] as String,
            textAlign: TextAlign.center,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        if (!_claimed)
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
        FilledButton(
          onPressed: _busy
              ? null
              : _claimed
              ? () => Navigator.pop(context)
              : _claim,
          child: Text(_claimed ? 'Merci !' : 'Réclamer mes 100 lunes'),
        ),
      ],
    ),
  );
}
