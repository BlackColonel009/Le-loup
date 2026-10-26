import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'classic_role.dart';

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
  const TavernBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final landscape = size.maxWidth > size.maxHeight;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/backgrounds/${landscape ? 'landscape' : 'portrait'}.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const ColoredBox(color: Color(0xB5101015)),
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
                    'Le deck Classique',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Explore les cinq rôles. Retourne une carte pour lire ses règles, '
                    'puis masque-la en la faisant glisser vers le bas.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Aperçu des bordures du verso — les rectos classiques sont conservés.',
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
                          final role = classicRoles[index];
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
                                      child: Image.asset(
                                        role.asset,
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
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
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Carte de rôle',
  barrierColor: const Color(0xEE080B10),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) =>
      RoleCardViewer(role: role, ambience: ambience),
);

class RoleCardViewer extends StatefulWidget {
  const RoleCardViewer({super.key, required this.role, required this.ambience});
  final ClassicRole role;
  final CardAmbience ambience;
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

  @override
  void initState() {
    super.initState();
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

  void _turn() {
    if (_closing || _flip.isAnimating) return;
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
                        : back
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
                              child: Image.asset(
                                widget.role.asset,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
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
            _flip.value > .5 ? 'Voir l’illustration' : 'Retourner la carte',
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
                _concealed ? 'Carte masquée' : widget.role.name,
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
                    Text(
                      'Camp : ${role.camp}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Action : ${role.phase}'),
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
