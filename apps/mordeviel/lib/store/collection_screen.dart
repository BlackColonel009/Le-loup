import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../audio/classic_audio.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import '../community/community_screen.dart';
import '../content/downloads_screen.dart';
import '../content/pack_store.dart';
import '../services/public_content.dart';
import '../social/social_api.dart';

const _gold = Color(0xFFD6B16D);

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  bool _busy = false, _signed = false;
  String _theme = 'classic';
  String? _error;
  Timer? _timer;
  final _laugh = AudioPlayer();
  @override
  void initState() {
    super.initState();
    _data = {
      'free_access': null,
      'daily_ids': <String>[],
      'products': [
        for (final role in [
          ...classicRoles,
          mayorOffice,
          configuredRole('villager', feminine: true),
        ])
          {
            'id': 'card-classic-${role.feminine ? 'villager_female' : role.id}',
            'kind': 'card',
            'theme': 'classic',
            'role_id': role.feminine ? 'villager_female' : role.id,
            'title': role.name,
            'owned': true,
            'accessible': true,
            'locked': false,
            'access_reason': 'owned',
            'claimable': false,
            'visible': 1,
            'shop': 0,
            'collector': 0,
          },
      ],
    };
    if (widget.initialTab == 1) _theme = 'intense';
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          !_busy) {
        _load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _laugh.stop();
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _laugh.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      Map<String, dynamic> data;
      try {
        data = await SocialApi.instance.request('/collection/me');
        _signed = true;
      } on SocialError catch (e) {
        if (e.status != 401 && e.status != 403) rethrow;
        data = await loadPublicContent('collection/catalog');
        _signed = false;
      }
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Collection non actualisée. Réessaie avec une connexion au serveur.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(Map p, bool collector) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await SocialApi.instance.request(
        '/collection/claim',
        method: 'POST',
        body: {
          'product_id': p['id'],
          'source': collector ? 'collector' : 'shop',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (result['granted'] as List).length > 1
                  ? 'Ajouté à ta collection, avec ses bonus !'
                  : 'Ajouté à ta collection !',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _hearCollector() async {
    final settings = ClassicAudio.instance;
    if (settings.muted || settings.effectLevel == 0) return;
    await PackStore.instance.initialize();
    final path = PackStore.instance.pathFor(
      'assets/audio/horror/witch_laugh.wav',
    );
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le rire d’ambiance est disponible dans le pack audio Horreur.',
            ),
          ),
        );
      }
      return;
    }
    await _laugh.stop();
    await _laugh.play(
      DeviceFileSource(path),
      volume: settings.effectLevel * .6,
    );
  }

  Widget _hero(bool collector) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _gold.withValues(alpha: .5)),
      gradient: const LinearGradient(
        colors: [Color(0xFF30263B), Color(0xFF15232A)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (collector)
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _hearCollector,
              child: Image.asset(
                'assets/store/collector.png',
                height: 230,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.auto_awesome, size: 100, color: _gold),
              ),
            ),
          ),
        Text(
          collector ? 'Le Collectionneur' : 'Tes cartes, tes histoires',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          collector
              ? '« Approche… cinq curiosités n’attendent que toi. Demain, qui sait ce que j’aurai déniché ? »'
              : 'Les classiques sont à toi dès le départ. Retrouve ici tes acquisitions et les cartes disponibles en essai.',
        ),
        const SizedBox(height: 10),
        Text(
          _data?['free_access'] == null
              ? 'Les classiques restent disponibles hors connexion. Connecte-toi pour actualiser les essais et acquisitions.'
              : _data?['free_access'] == true
              ? 'Accès gratuit temporaire · les essais ne sont pas des acquisitions.'
              : 'Restrictions actives · les cartes acquises et les essais programmés restent accessibles.',
          style: const TextStyle(color: _gold),
        ),
        if (collector) ...[
          const SizedBox(height: 8),
          const Text(
            '5 cartes par jour · parfois une voix ou un environnement rare. Renouvellement à minuit UTC.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          TextButton.icon(
            onPressed: _hearCollector,
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Son rire d’ambiance'),
          ),
        ],
      ],
    ),
  );
  Widget _product(Map p, bool collector) {
    final locked = p['locked'] == true, owned = p['owned'] == true;
    final card = p['kind'] == 'card';
    final ambience = CardAmbience.values.firstWhere(
      (v) => v.asset == p['theme'],
      orElse: () => CardAmbience.classic,
    );
    final id = p['role_id'] as String;
    final role = card
        ? configuredRole(
            id == 'villager_female' ? 'villager' : id,
            feminine: id == 'villager_female',
            edition: ambience.asset,
          )
        : null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: role != null && !locked
                    ? () => showRoleCard(context, role, ambience: ambience)
                    : null,
                child: LockedCardVisual(
                  locked: locked,
                  horror: ambience == CardAmbience.horror,
                  seed: p['id'].hashCode,
                  child: role != null
                      ? RoleCardFront(role: role, ambience: ambience)
                      : Icon(
                          card
                              ? Icons.style
                              : p['kind'] == 'voice'
                              ? Icons.record_voice_over
                              : Icons.landscape,
                          size: 58,
                          color: _gold,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p['title'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              owned
                  ? 'Dans ta collection'
                  : locked
                  ? 'À collectionner'
                  : p['access_reason'] == 'trial'
                  ? 'Essai du moment'
                  : 'Accès gratuit temporaire',
              style: TextStyle(
                fontSize: 11,
                color: owned ? Colors.greenAccent : _gold,
              ),
            ),
            if (!owned) ...[
              if ((p['free_days_remaining'] as num? ?? 0) > 0)
                Text(
                  'Gratuit · encore ${p['free_days_remaining']} jour${p['free_days_remaining'] == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _gold,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (p['price_minor'] != null)
                Text(
                  'Prix prévu : ${((p['price_minor'] as num) / (p['currency'] == 'XOF' ? 1 : 100)).toStringAsFixed(p['currency'] == 'XOF' ? 0 : 2)} ${p['currency']}',
                  style: const TextStyle(fontSize: 11),
                ),
              if ((p['bonus'] as List? ?? []).isNotEmpty)
                const Text(
                  'Bonus inclus',
                  style: TextStyle(color: _gold, fontSize: 11),
                ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    !_busy &&
                        p['claimable'] == true &&
                        (collector ? p['collector'] == 1 : p['shop'] == 1)
                    ? () => _claim(p, collector)
                    : null,
                child: Text(
                  p['price_minor'] == null
                      ? 'Bientôt disponible'
                      : p['purchase_label'] as String,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _page(bool collector) {
    final all = (_data?['products'] as List? ?? []).cast<Map>();
    final selected = all.where(
      (p) => collector
          ? (_data?['daily_ids'] as List? ?? []).contains(p['id']) &&
                p['visible'] == 1 &&
                p['collector'] == 1
          : p['theme'] == _theme,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(child: _hero(collector)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (!_signed)
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const CommunityScreen(),
                          ),
                        );
                        await _load();
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text(
                        'Se connecter pour conserver sa collection',
                      ),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  if (!collector)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final theme in CardAmbience.values)
                          ChoiceChip(
                            label: Text(theme.label),
                            selected: _theme == theme.asset,
                            onSelected: (_) =>
                                setState(() => _theme = theme.asset),
                          ),
                      ],
                    ),
                  if (collector)
                    Text(
                      'Les trouvailles du ${_data?['day'] ?? 'jour'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const DownloadsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Télécharger les visuels et les voix'),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (!_busy && selected.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Les étagères attendent la prochaine connexion.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
                    .clamp(1.0, 2.0);
                final columns =
                    (constraints.crossAxisExtent / (scale > 1.3 ? 240 : 165))
                        .floor()
                        .clamp(1, 5);
                final list = selected.toList();
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _product(list[i], collector),
                    childCount: list.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 390 + (scale - 1) * 110,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: widget.initialTab,
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Le cabinet des curiosités'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser la collection',
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Ma collection'),
            Tab(text: 'Collectionneur'),
          ],
        ),
      ),
      body: TabBarView(children: [_page(false), _page(true)]),
    ),
  );
}

class LockedCardVisual extends StatefulWidget {
  const LockedCardVisual({
    super.key,
    required this.child,
    required this.locked,
    required this.horror,
    this.seed = 0,
  });
  final Widget child;
  final bool locked, horror;
  final int seed;
  @override
  State<LockedCardVisual> createState() => _LockedCardVisualState();
}

class _LockedCardVisualState extends State<LockedCardVisual>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LockedCardVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.locked && !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.locked ? 'Carte verrouillée' : 'Carte disponible',
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (_, child) {
          final phase = (_motion.value + (widget.seed.abs() % 11) / 11) % 1;
          final strength = widget.locked && _motion.isAnimating && phase < .2
              ? math.sin(phase * math.pi / .2)
              : 0.0;
          final shake = math.sin(phase * math.pi * 100) * strength;
          return Transform.translate(
            offset: Offset(shake * 3, 0),
            child: Transform.rotate(angle: shake * .018, child: child),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.locked) ...[
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: widget.horror ? .50 : .37,
                ),
              ),
              if (widget.horror)
                Image.asset(
                  'assets/store/horror_chains.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.lock, size: 60, color: Colors.white70),
                )
              else
                Center(
                  child: FractionallySizedBox(
                    widthFactor: .43,
                    child: Image.asset(
                      'assets/store/gold_lock.png',
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.lock, size: 55, color: _gold),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
