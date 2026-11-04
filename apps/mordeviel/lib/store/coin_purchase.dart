import 'package:flutter/material.dart';
import '../coins/coin_widgets.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';

Future<bool> buyWithCoins(
  BuildContext context,
  Map product, {
  required String day,
  required int balance,
  String source = 'shop',
}) async {
  final price = product['coin_price'] as int;
  if (balance < price) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Il te manque ${price - balance} Lunes d’or. Joue des parties pour en gagner !',
        ),
      ),
    );
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ajouter à ma collection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinToken(size: 60),
          const SizedBox(height: 16),
          Text('${product['title']}', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            '$price Lunes d’or',
            style: const TextStyle(
              color: coinGold,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Acquisition définitive.\nIl te restera ${balance - price} Lunes d’or.',
            textAlign: TextAlign.center,
          ),
          if ((product['bonus'] as List? ?? []).isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Les bonus de cette offre sont inclus.'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmer l’achat'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    final result = await SocialApi.instance.request(
      '/shop/purchase',
      method: 'POST',
      body: {
        'product_id': product['id'],
        'day': day,
        'expected_price': price,
        'source': source,
      },
    );
    SocialService.instance.updateCoinBalance(
      result['balance'] as int,
      forUser: result['user_id'] as int,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['already_owned'] == true
                ? 'Tu possèdes déjà cet article. Aucune lune débitée.'
                : 'Ajouté à ta collection !',
          ),
        ),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SocialError
                ? error.message
                : 'Achat interrompu. Actualise la boutique avant de réessayer.',
          ),
        ),
      );
    }
    return false;
  }
}
