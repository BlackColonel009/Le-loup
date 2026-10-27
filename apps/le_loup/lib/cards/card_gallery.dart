import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'classic_role.dart';
import '../design/drifting_backdrop.dart';

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
                  Text(
                    'Les cartes du village',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore les ${classicRoles.length} rôles. Retourne une carte pour lire ses règles, '
                    'puis masque-la en la faisant glisser vers le bas.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les 17 rôles sont disponibles en partie. Consulte leurs pouvoirs et leurs conditions de victoire au verso.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Classique, Intense ou Horreur : mêmes rôles, mêmes pouvoirs. Seul le design change. '
                    'Intense : 16 illustrations disponibles ; seul le Bouc émissaire reste illustré en Classique. '
                    'Les illustrations Horreur seront ajoutées prochainement.',
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
                          onSelected: (_) =>
                              setState(() => _ambience = ambience),
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
                        itemCount: classicRoles.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.63,
                        ),
                        itemBuilder: (context, index) {
                          final role = configuredRole(
                            classicRoles[index].id,
                            feminine: _feminine,
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
  late final _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final _hide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  bool _closing = false;
  bool _concealed = false;
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
      setState(() => _concealed = true);
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
    setState(() => _closing = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _hide.forward();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _turn() async {
    if (_closing || _flip.isAnimating) return;
    if (_covered) {
      if (!MediaQuery.disableAnimationsOf(context)) await _flip.forward();
      if (mounted) {
        setState(() {
          _covered = false;
          _flip.value = 0;
        });
      }
      return;
    }
    final back = _flip.value > 0.5;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = back ? 0 : 1;
    } else if (back) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  Widget _card() => LayoutBuilder(
    builder: (context, size) {
      final width = math.min(
        440.0,
        math.min(size.maxWidth, size.maxHeight * .7),
      );
      return Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, _hide]),
          builder: (context, child) {
            final back = _flip.value > .5;
            final angle = Curves.easeInOut.transform(_flip.value) * math.pi;
            return Transform.translate(
              offset: Offset(
                0,
                Curves.easeInCubic.transform(_hide.value) *
                    (MediaQuery.sizeOf(context).height + 180),
              ),
              child: Opacity(
                opacity: 1 - _hide.value,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .001)
                    ..rotateY(back ? angle - math.pi : angle),
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
                        ? Image.asset(
                            widget.ambience == CardAmbience.intense
                                ? 'assets/village/intense/card_back.png'
                                : 'assets/village/card_back.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'Carte secrète face cachée',
                          )
                        : back && !_covered
                        ? _CardBack(
                            role: widget.role,
                            ambience: widget.ambience,
                          )
                        : GestureDetector(
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) > 250) {
                                _dismiss();
                              }
                            },
                            child: Semantics(
                              label:
                                  'Recto illustré de ${widget.role.name}. Retournez pour lire les règles.',
                              image: true,
                              child: RoleCardFront(
                                role: widget.role,
                                ambience: widget.ambience,
                              ),
                            ),
                          ),
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
    if (!_concealed)
      AnimatedBuilder(
        animation: _flip,
        builder: (context, child) => FilledButton.icon(
          onPressed: _closing || _flip.isAnimating ? null : _turn,
          icon: const Icon(Icons.flip),
          label: Text(
            _covered
                ? 'Découvrir ma carte'
                : _flip.value > .5
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

/// Text is rendered from the same role definition for every cosmetic edition.
/// The imported JPGs are kept intact; their outdated rules are covered here.
class RoleCardFront extends StatelessWidget {
  const RoleCardFront({super.key, required this.role, required this.ambience});
  final ClassicRole role;
  final CardAmbience ambience;

  static bool hasIntense(String id) =>
      id != 'scapegoat' && classicRoles.any((role) => role.id == id);

  @override
  Widget build(BuildContext context) {
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
              Image.asset(
                role.id == 'villager' && role.feminine
                    ? 'assets/cards/intense/villager_female.png'
                    : 'assets/cards/intense/${role.id}_intense.jpg',
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
                            fontFamily: 'SourceSans3',
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
                      'Même rôle et mêmes pouvoirs dans toutes les éditions.',
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
