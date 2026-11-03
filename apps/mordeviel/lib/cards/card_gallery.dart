import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'classic_role.dart';
import '../design/drifting_backdrop.dart';
import '../content/content_image.dart';
import 'package:flutter/physics.dart';
import 'card_motion.dart';
import '../services/immersion_preferences.dart';
import '../audio/card_foley.dart';
import 'package:local_host/card_variants.dart' show cardVariant;
import '../profile/avatar_gallery.dart';
import '../content/require_packs.dart';

enum CardAmbience {
  classic('Classique', 'classic'),
  intense('Intense', 'intense'),
  horror('Horreur', 'horror');

  const CardAmbience(this.label, this.asset);
  final String label;
  final String asset;
}

/// Décor adaptatif : chaque orientation possède son propre fichier source.
class TavernBackground extends StatelessWidget {
  const TavernBackground({
    super.key,
    required this.child,
    this.dim = .71,
    this.animate = false,
  });
  final Widget child;
  final double dim;
  final bool animate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final landscape = size.maxWidth > size.maxHeight;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (animate)
            Positioned.fill(
              child: RepaintBoundary(
                child: DriftingBackdrop(
                  child: Image.asset(
                    'assets/backgrounds/${landscape ? 'landscape' : 'portrait'}.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            )
          else
            Image.asset(
              'assets/backgrounds/${landscape ? 'landscape' : 'portrait'}.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ColoredBox(color: const Color(0xFF101015).withValues(alpha: dim)),
          child,
        ],
      );
    },
  );
}

class CardGalleryScreen extends StatefulWidget {
  const CardGalleryScreen({super.key});
  @override
  State<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends State<CardGalleryScreen> {
  CardAmbience _ambience = CardAmbience.classic;
  bool _feminine = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Les cartes du village')),
    body: TavernBackground(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.face_retouching_natural),
                      title: const Text('Découvrir les avatars des joueurs'),
                      subtitle: const Text(
                        '4 portraits Classiques disponibles · cadeaux de défis',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AvatarGalleryScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Les cartes du village',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore les ${classicRoles.length} rôles et la fonction de Maire. Retourne une carte pour lire ses règles, '
                    'puis masque-la en la faisant glisser vers le bas.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les 18 rôles et le titre public de Maire possèdent leurs fiches. Consulte les pouvoirs et les conditions de victoire au verso.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Chaque rôle possède une variante Intense et une variante Horreur. En partie mixte, le pouvoir suit chaque carte et son édition. Consulte le dos des cartes et le Codex avant la partie.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ambience in CardAmbience.values)
                        ChoiceChip(
                          label: Text(ambience.label),
                          selected: _ambience == ambience,
                          onSelected: (_) async {
                            final packs = switch (ambience) {
                              CardAmbience.intense => ['intense-cards'],
                              CardAmbience.horror => ['horror-cards'],
                              _ => <String>[],
                            };
                            if (!await ensurePacksAvailable(
                                  context,
                                  packs,
                                  reason:
                                      'Installe les cartes de cette collection pour les découvrir.',
                                ) ||
                                !mounted) {
                              return;
                            }
                            setState(() => _ambience = ambience);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voir la Villageoise'),
                    subtitle: const Text(
                      'Même rôle et mêmes pouvoirs que le Villageois.',
                    ),
                    value: _feminine,
                    onChanged: (value) => setState(() => _feminine = value),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 800
                          ? 4
                          : constraints.maxWidth >= 520
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: collectionCards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.63,
                        ),
                        itemBuilder: (context, index) {
                          final role = configuredRole(
                            collectionCards[index].id,
                            feminine: _feminine,
                            edition: _ambience.asset,
                          );
                          return Semantics(
                            button: true,
                            label: 'Consulter ${role.name}',
                            child: InkWell(
                              onTap: () => showRoleCard(
                                context,
                                role,
                                ambience: _ambience,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: RoleCardFront(
                                        role: role,
                                        ambience: _ambience,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    role.name,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  if (!role.implemented)
                                    const Text(
                                      'Pouvoir à intégrer',
                                      style: TextStyle(fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showRoleCard(
  BuildContext context,
  ClassicRole role, {
  CardAmbience ambience = CardAmbience.classic,
  bool covered = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Carte de rôle',
  barrierColor: const Color(0xEE080B10),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) =>
      RoleCardViewer(role: role, ambience: ambience, covered: covered),
);

class RoleCardViewer extends StatefulWidget {
  const RoleCardViewer({
    super.key,
    required this.role,
    required this.ambience,
    this.covered = false,
  });
  final ClassicRole role;
  final CardAmbience ambience;
  final bool covered;
  @override
  State<RoleCardViewer> createState() => _RoleCardViewerState();
}

class _RoleCardViewerState extends State<RoleCardViewer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _flip = AnimationController.unbounded(vsync: this);
  late final _hide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  bool _closing = false;
  bool _concealed = false;
  bool _peeking = false;
  bool _dragging = false;
  int _turnGeneration = 0;
  late bool _covered;

  @override
  void initState() {
    super.initState();
    _covered = widget.covered;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted && !_concealed) {
      _turnGeneration++;
      _flip.stop();
      setState(() {
        _concealed = true;
        _peeking = false;
        _dragging = false;
      });
      // Cache immédiatement la carte quand l'application perd le premier plan.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flip.dispose();
    _hide.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _turnGeneration++;
    _flip.stop();
    setState(() {
      _closing = true;
      _peeking = false;
    });
    CardFoley.play();
    if (!ImmersionPreferences.instance.reduced(context)) {
      await _hide.forward();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _turn() async {
    if (_closing || _concealed || _dragging || _flip.isAnimating) return;
    _peek(false);
    ImmersionPreferences.instance.touch();
    CardFoley.play();
    await _settleTurn(_flip.value.roundToDouble() + 1, 0);
  }

  void _startTurn() {
    if (_closing || _concealed) return;
    _turnGeneration++;
    _flip.stop();
    _peek(false);
    setState(() => _dragging = true);
    ImmersionPreferences.instance.touch();
    CardFoley.play();
  }

  void _dragTurn(double delta) {
    if (!_dragging || _closing || _concealed) return;
    final next = _flip.value + delta;
    _flip.value = _covered ? next.clamp(-1.0, 1.0) : next;
  }

  void _releaseTurn(double velocity) {
    if (!_dragging || _closing || _concealed) return;
    var target = cardTurnTarget(_flip.value, velocity);
    if (_covered) target = target.clamp(-1.0, 1.0);
    _settleTurn(target, velocity);
  }

  void _cancelTurn() {
    if (!_dragging || _closing || _concealed) return;
    _settleTurn(_covered ? 0 : _flip.value.roundToDouble(), 0);
  }

  Future<void> _settleTurn(double target, double velocity) async {
    final generation = ++_turnGeneration;
    setState(() => _dragging = false);
    if (ImmersionPreferences.instance.reduced(context)) {
      _flip.value = target;
    } else {
      try {
        await _flip
            .animateWith(
              SpringSimulation(cardTurnSpring, _flip.value, target, velocity),
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted || generation != _turnGeneration || _concealed || _closing) {
      return;
    }
    if (_covered && target.round().isOdd) {
      setState(() {
        _covered = false;
        _flip.value = 0;
      });
    } else {
      // Equivalent physical pose, without accumulating huge angle values.
      _flip.value = (target.round() % 2).toDouble();
    }
  }

  void _peek(bool value) {
    if (!mounted ||
        value == _peeking ||
        value && (!_covered || _concealed || _closing)) {
      return;
    }
    setState(() => _peeking = value);
  }

  Widget _card() => LayoutBuilder(
    builder: (context, size) {
      final width = math.min(
        440.0,
        math.min(size.maxWidth, size.maxHeight * .7),
      );
      final front = Semantics(
        label:
            'Recto illustré de ${widget.role.name}. Retournez pour lire les règles.',
        image: true,
        child: widget.ambience == CardAmbience.classic
            ? RoleCardFront(role: widget.role, ambience: widget.ambience)
            : CardFinish(
                horror: widget.ambience == CardAmbience.horror,
                child: RoleCardFront(
                  role: widget.role,
                  ambience: widget.ambience,
                ),
              ),
      );
      final rules = _CardBack(role: widget.role, ambience: widget.ambience);
      return Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, _hide]),
          builder: (context, child) {
            final back = cardFaceIsBack(_flip.value);
            return Transform.translate(
              offset: Offset(
                0,
                Curves.easeInCubic.transform(_hide.value) *
                    (MediaQuery.sizeOf(context).height + 180),
              ),
              child: Opacity(
                opacity: 1 - _hide.value,
                child: CardMotion(
                  enabled: !_closing && !_concealed,
                  halfTurns: _flip.value,
                  onTurnStart: _startTurn,
                  onTurnUpdate: _dragTurn,
                  onTurnEnd: _releaseTurn,
                  onTurnCancel: _cancelTurn,
                  canPeek: _covered && !_concealed && !_closing,
                  onPeek: _peek,
                  onDismiss: _dismiss,
                  child: SizedBox(
                    width: width,
                    height: width / .7,
                    child: _concealed
                        ? const Card(
                            child: Center(
                              child: Icon(Icons.visibility_off, size: 64),
                            ),
                          )
                        : _covered && !back
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ContentImage(
                                widget.ambience == CardAmbience.horror
                                    ? 'assets/village/horror/card_back.png'
                                    : widget.ambience == CardAmbience.intense
                                    ? 'assets/village/intense/card_back.png'
                                    : 'assets/village/card_back.png',
                                fit: BoxFit.contain,
                                fallbackAsset: 'assets/village/card_back.png',
                              ),
                              if (_peeking)
                                ClipPath(
                                  key: const ValueKey('secret-card-peek'),
                                  clipper: PeekCornerClip(),
                                  child: ExcludeSemantics(
                                    child: RoleCardFront(
                                      role: widget.role,
                                      ambience: widget.ambience,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : back && !_covered
                        ? rules
                        : front,
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  List<Widget> _buttons() => [
    if (_covered && !_concealed)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Maintiens un coin de la carte pour un coup d’œil. Relâche pour masquer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    if (!_concealed)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Glisse sur les côtés pour retourner la carte. Un geste vif la fait tournoyer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    if (!_concealed)
      AnimatedBuilder(
        animation: _flip,
        builder: (context, child) => FilledButton.icon(
          onPressed: _closing || _dragging || _flip.isAnimating ? null : _turn,
          icon: const Icon(Icons.flip),
          label: Text(
            _covered
                ? 'Découvrir ma carte'
                : cardFaceIsBack(_flip.value)
                ? 'Voir l’illustration'
                : 'Retourner la carte',
          ),
        ),
      ),
    TextButton.icon(
      onPressed: _closing ? null : _dismiss,
      icon: const Icon(Icons.keyboard_arrow_down),
      label: const Text('Cacher la carte'),
    ),
  ];

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _closing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _dismiss();
    },
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, size) {
              final title = Text(
                _concealed
                    ? 'Carte masquée'
                    : _covered
                    ? 'Ma carte secrète'
                    : widget.role.name,
                style: Theme.of(context).textTheme.titleLarge,
              );
              if (size.maxWidth > size.maxHeight && size.maxWidth > 560) {
                return Row(
                  children: [
                    Expanded(child: _card()),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: math.min(280, size.maxWidth * .4),
                      child: SingleChildScrollView(
                        primary: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            title,
                            const SizedBox(height: 24),
                            ..._buttons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  title,
                  const SizedBox(height: 12),
                  Expanded(child: _card()),
                  const SizedBox(height: 12),
                  ..._buttons(),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Edition-specific rules cover the old caption without changing the artwork.
class RoleCardFront extends StatelessWidget {
  const RoleCardFront({super.key, required this.role, required this.ambience});
  final ClassicRole role;
  final CardAmbience ambience;

  static bool hasIntense(String id) =>
      id == 'mayor' || classicRoles.any((role) => role.id == id);

  @override
  Widget build(BuildContext context) {
    final variant = cardVariant(role.id, ambience.asset);
    if (variant != null) {
      final horror = ambience == CardAmbience.horror;
      final asset = horror
          ? 'assets/cards/horror/${role.id == 'villager' && role.feminine ? 'villager_female' : role.id}.png'
          : role.id == 'villager' && role.feminine
          ? 'assets/cards/intense/villager_female.png'
          : 'assets/cards/intense/${role.id}_intense.${['sisters', 'mayor', 'scapegoat'].contains(role.id) ? 'png' : 'jpg'}';
      return Center(
        child: AspectRatio(
          aspectRatio: horror ? 2 / 3 : 864 / 1238,
          child: LayoutBuilder(
            builder: (context, size) => Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  asset,
                  fallbackAsset: role.asset,
                  fit: BoxFit.fill,
                  cacheWidth: 864,
                ),
                Positioned(
                  left: size.maxWidth * .14,
                  right: size.maxWidth * .14,
                  top:
                      size.maxHeight *
                      (horror
                          ? .66
                          : role.id == 'metamorph'
                          ? .54
                          : .625),
                  bottom: size.maxHeight * (horror ? .105 : .135),
                  child: _VariantPlate(
                    variant: variant,
                    camp: role.camp,
                    horror: horror,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (ambience == CardAmbience.horror) {
      return ContentImage(
        'assets/cards/horror/${role.id == 'villager' && role.feminine ? 'villager_female' : role.id}.png',
        fallbackAsset: role.asset,
        cacheWidth: 768,
      );
    }
    if (ambience != CardAmbience.intense || !hasIntense(role.id)) {
      return Image.asset(
        role.asset,
        cacheWidth: 768,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 864 / 1238,
        child: LayoutBuilder(
          builder: (context, size) => Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(
                role.id == 'villager' && role.feminine
                    ? 'assets/cards/intense/villager_female.png'
                    : ['sisters', 'mayor', 'scapegoat'].contains(role.id)
                    ? 'assets/cards/intense/${role.id}_intense.png'
                    : 'assets/cards/intense/${role.id}_intense.jpg',
                fallbackAsset: role.asset,
                cacheWidth: 864,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
              Positioned(
                left: size.maxWidth * .145,
                right: size.maxWidth * .145,
                top: size.maxHeight * (role.id == 'metamorph' ? .62 : .695),
                height: size.maxHeight * (role.id == 'metamorph' ? .18 : .173),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE1CAA0), Color(0xFFC6A36B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(size.maxWidth * .012),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size.maxWidth * .012),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 580,
                        child: Text(
                          'Camp : ${role.camp}\n${role.summary}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'VillageSans',
                            fontSize: 28,
                            height: 1.13,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantPlate extends StatelessWidget {
  const _VariantPlate({
    required this.variant,
    required this.camp,
    required this.horror,
  });
  final Map<String, String> variant;
  final String camp;
  final bool horror;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: horror ? const Color(0xFF563322) : const Color(0xFFAA7E42),
        width: 1.5,
      ),
      gradient: LinearGradient(
        colors: horror
            ? const [Color(0xFFDEC5A3), Color(0xFFECD9B9), Color(0xFFCCAD86)]
            : const [Color(0xFFDBC08C), Color(0xFFF0DFB8), Color(0xFFC6A36B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 620,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'VillageSans',
              color: Color(0xFF2B1B12),
              fontSize: 36,
              height: 1.16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  variant['name']!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: horror
                        ? const Color(0xFF661B1B)
                        : const Color(0xFF493016),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Camp : $camp',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  variant['summary']!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.role, required this.ambience});
  final ClassicRole role;
  final CardAmbience ambience;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      image: DecorationImage(
        image: AssetImage('assets/frames/${ambience.asset}.jpg'),
        fit: BoxFit.fill,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, size) => Padding(
        // Zones intérieures communes aux trois cadres, sans recouvrir leurs ornements.
        padding: EdgeInsets.fromLTRB(
          size.maxWidth * .14,
          size.maxHeight * .14,
          size.maxWidth * .14,
          size.maxHeight * .15,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEEDDB9).withValues(alpha: .96),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Color(0xFF2B1B12),
                  fontSize: 16,
                  height: 1.4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!role.implemented) ...[
                      const Text(
                        'Fiche de collection · Pouvoir à intégrer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Camp : ${role.camp}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Action : ${role.phase}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Les règles de cette carte s’appliquent aussi en partie mixte. Consulte le Codex pour les réglages du salon.',
                    ),
                    const Divider(color: Color(0x88755036), height: 24),
                    Text(role.summary),
                    const SizedBox(height: 16),
                    const Text(
                      'Précisions du jeu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(role.details),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
