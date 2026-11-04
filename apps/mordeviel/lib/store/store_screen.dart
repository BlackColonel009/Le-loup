import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show chatStickerById;
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import '../coins/coin_widgets.dart';
import '../community/community_screen.dart';
import '../content/downloads_screen.dart';
import '../profile/avatar_border.dart';
import '../services/public_content.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import '../stickers/chat_stickers.dart';
import 'coin_purchase.dart';
import 'collection_screen.dart';

const shopNotice =
    'Des trouvailles chaque jour, à collectionner avec tes Lunes d’or.';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _error;
  String _filter = 'all';
  bool _loading = false, _buying = false, _signed = false;
  Timer? _timer;
  DateTime? _lastRotationAttempt;
  List<Map> get _products => (_data?['products'] as List? ?? []).cast<Map>();
  int get _balance => (_data?['balance'] as int?) ?? 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        return;
      }
      final now = DateTime.now();
      final deadline = DateTime.tryParse(
        _data?['next_rotation'] as String? ?? '',
      );
      if (deadline != null &&
          !now.isBefore(deadline) &&
          !_loading &&
          !_buying &&
          (_lastRotationAttempt == null ||
              now.difference(_lastRotationAttempt!).inSeconds >= 30)) {
        _lastRotationAttempt = now;
        unawaited(_load());
      }
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _buying) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;
      var signed = true;
      try {
        data = await SocialApi.instance.request('/shop/me');
      } on SocialError catch (error) {
        if (error.status != 401 && error.status != 403) rethrow;
        data = await loadPublicContent('shop/catalog');
        signed = false;
      }
      if (!mounted) return;
      if (signed) {
        SocialService.instance.updateCoinBalance(
          data['balance'] as int,
          forUser: data['user_id'] as int,
        );
      }
      setState(() {
        _data = data;
        _signed = signed;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Les offres sont indisponibles pour le moment. Vérifie ta connexion puis réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(Map p) async {
    if (_buying || _loading) return;
    setState(() => _buying = true);
    try {
      await buyWithCoins(
        context,
        p,
        day: _data!['day'] as String,
        balance: _balance,
      );
    } finally {
      if (mounted) {
        setState(() => _buying = false);
        await _load();
      }
    }
  }

  Future<void> _login() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityScreen()),
    );
    if (mounted) await _load();
  }

  String get _countdown {
    final next = DateTime.tryParse(_data?['next_rotation'] as String? ?? '');
    if (next == null) return 'Chaque jour à minuit UTC';
    final seconds = next.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    String pad(int n) => '$n'.padLeft(2, '0');
    return '${pad(seconds ~/ 3600)}:${pad(seconds ~/ 60 % 60)}:${pad(seconds % 60)}';
  }

  Widget _visual(Map p) {
    final id = p['role_id'] as String;
    if (p['kind'] == 'card') {
      return RoleCardFront(
        role: configuredRole(
          id == 'villager_female' ? 'villager' : id,
          feminine: id == 'villager_female',
          edition: 'intense',
        ),
        ambience: CardAmbience.intense,
      );
    }
    if (p['kind'] == 'sticker' && chatStickerById(id) != null) {
      return Center(
        child: ChatStickerImage(sticker: chatStickerById(id)!, size: 130),
      );
    }
    if (p['kind'] == 'border' && p['border'] is Map) {
      return Center(
        child: SizedBox.square(
          dimension: 130,
          child: AnimatedAvatarBorder(
            border: p['border'] as Map,
            child: const Padding(
              padding: EdgeInsets.all(17),
              child: CircleAvatar(
                backgroundColor: Color(0xFF263342),
                child: Icon(Icons.person, size: 54, color: coinGold),
              ),
            ),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.auto_awesome, size: 64, color: coinGold),
    );
  }

  Widget _product(Map p) {
    final owned = p['owned'] == true;
    final price = p['coin_price'] as int;
    final missing = price - _balance;
    return Card(
      key: ValueKey('offer-${p['id']}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _visual(p)),
            const SizedBox(height: 12),
            Text(
              p['title'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(switch (p['kind']) {
              'card' => 'Carte Intense · définitive',
              'border' => 'Bordure de profil',
              _ => 'Sticker à collectionner',
            }, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 10),
            Row(
              children: [
                const CoinToken(size: 24),
                const SizedBox(width: 8),
                Text(
                  '$price',
                  style: const TextStyle(
                    color: coinGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
                if (owned)
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('buy-${p['id']}'),
              onPressed: owned || _buying || _loading
                  ? null
                  : !_signed
                  ? _login
                  : () => _buy(p),
              child: Text(
                owned
                    ? 'Acquis'
                    : !_signed
                    ? 'Se connecter'
                    : missing > 0
                    ? 'Il manque $missing'
                    : 'Acheter',
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Boutique des Lunes'),
      actions: [
        IconButton(
          onPressed: _loading || _buying ? null : _load,
          tooltip: 'Actualiser les offres',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: coinGold.withValues(alpha: .45),
                      ),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF362837), Color(0xFF142832)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Le comptoir du village',
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 30,
                            color: coinGold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(shopNotice),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const CoinToken(size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _signed
                                    ? '$_balance Lunes d’or'
                                    : 'Connecte-toi pour retrouver ta bourse',
                                style: const TextStyle(
                                  fontSize: 19,
                                  color: coinGold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Prochaines offres dans $_countdown',
                          key: const ValueKey('shop-countdown'),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '3 stickers · 3 cartes Intenses · 3 bordures\nRenouvellement à minuit UTC.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CollectionScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.collections_bookmark_outlined),
                        label: const Text('Ma collection'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CollectionScreen(initialTab: 1),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Collectionneur'),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Télécharger les visuels'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'all': 'Tout',
                        'sticker': 'Stickers',
                        'card': 'Cartes Intenses',
                        'border': 'Bordures',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _filter == entry.key,
                          onSelected: (_) =>
                              setState(() => _filter = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_loading || _buying) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  if (!_loading && _data != null && _products.isEmpty)
                    const Text(
                      'Les étagères sont vides aujourd’hui. Reviens demain !',
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
                    .clamp(1.0, 2.0);
                final columns =
                    (constraints.crossAxisExtent / (scale > 1.3 ? 250 : 180))
                        .floor()
                        .clamp(1, 5);
                final items = _products
                    .where((p) => _filter == 'all' || p['kind'] == _filter)
                    .toList();
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _product(items[i]),
                    childCount: items.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 380 + (scale - 1) * 130,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
