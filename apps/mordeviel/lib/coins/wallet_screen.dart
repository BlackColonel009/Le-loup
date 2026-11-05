import 'package:flutter/material.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import 'coin_widgets.dart';
import 'coin_reward_scene.dart';
import 'creator_gift.dart';
import '../store/store_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SocialApi.instance.request('/coins/me');
      if (!mounted) return;
      SocialService.instance.updateCoinBalance(
        data['balance'] as int,
        forUser: data['user_id'] as int,
      );
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SocialError
              ? error.message
              : 'Ta bourse est indisponible pour le moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ma bourse'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          const SizedBox(height: 22),
          const Center(child: CoinToken(size: 90)),
          const SizedBox(height: 16),
          Text(
            '${_data?['balance'] ?? 0}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: coinGold,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            coinName,
            textAlign: TextAlign.center,
            style: TextStyle(color: coinGold, fontSize: 20),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const CoinToken(size: 44, metal: MoonMetal.bronze),
              title: Text('${_data?['bronze_balance'] ?? 0} Lunes bronze'),
              subtitle: const Text('Gains et utilisation à venir'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tes Lunes d’or sont conservées sur ton compte. Échange-les dans la boutique contre des articles pour ta collection.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
              if (mounted) await _load();
            },
            icon: const Icon(Icons.storefront),
            label: const Text('Voir les offres du jour'),
          ),
          if (_data?['creator_gift'] is Map &&
              _data!['creator_gift']['claimed'] != true)
            Card(
              child: ListTile(
                leading: const Icon(Icons.card_giftcard, color: coinGold),
                title: const Text('Le Créateur t’offre 100 lunes'),
                subtitle: const Text(
                  'Depuis la version 0.3.5 · Une fois par compte',
                ),
                onTap: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => CreatorGiftDialog(
                      gift: Map<String, dynamic>.from(
                        _data!['creator_gift'] as Map,
                      ),
                    ),
                  );
                  if (mounted) await _load();
                },
              ),
            ),
          for (final gift in (_data?['gifts'] as List? ?? []).cast<Map>())
            ListTile(
              leading: const Icon(Icons.redeem, color: coinGold),
              title: const Text('Cadeau unique du Créateur'),
              trailing: Text(
                '+${gift['amount']}',
                style: const TextStyle(color: coinGold),
              ),
            ),
          if ((_data?['purchases'] as List? ?? []).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Tes derniers achats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final purchase in (_data!['purchases'] as List).cast<Map>())
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(purchase['title'] as String),
                trailing: Text(
                  '−${purchase['amount']}',
                  style: const TextStyle(color: coinGold),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            'Tes derniers gains',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final reward in (_data?['rewards'] as List? ?? []).cast<Map>())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CoinToken(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${reward['participant_role'] == 'mdj'
                                ? 'Récompense du MDJ'
                                : reward['won'] == true
                                ? 'Victoire'
                                : 'Défaite'} · ${switch (reward['theme']) {
                              'horror' => 'Horreur',
                              'intense' => 'Intense',
                              _ => 'Classique',
                            }}\n${reward['nights']} nuit(s)',
                          ),
                        ),
                        Text(
                          '+${reward['amount']}',
                          style: const TextStyle(
                            color: coinGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (reward['claimed_at'] == null)
                      TextButton.icon(
                        icon: const Icon(Icons.redeem),
                        label: const Text('Ouvrir le coffre'),
                        onPressed: () async {
                          await showCoinReward(
                            context,
                            Map<String, dynamic>.from(reward),
                          );
                          if (mounted) await _load();
                        },
                      ),
                  ],
                ),
              ),
            ),
          if (_data != null && (_data!['rewards'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Termine une partie en ligne pour remplir ta bourse.',
              ),
            ),
        ],
      ),
    ),
  );
}
