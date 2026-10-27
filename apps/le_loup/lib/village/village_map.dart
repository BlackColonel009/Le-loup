import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:local_host/local_host.dart';
import 'weather_overlay.dart';
import 'house_sprite_geometry.dart';
import 'guardian_aura.dart';

/// Centres des vingt fondations de la map Intense v2.
const intenseVillagePlots = <Offset>[
  Offset(.414, .445),
  Offset(.586, .445),
  Offset(.296, .585),
  Offset(.704, .585),
  Offset(.305, .450),
  Offset(.695, .450),
  Offset(.416, .700),
  Offset(.584, .700),
  Offset(.355, .385),
  Offset(.645, .385),
  Offset(.438, .350),
  Offset(.562, .350),
  Offset(.200, .430),
  Offset(.800, .430),
  Offset(.180, .585),
  Offset(.820, .585),
  Offset(.220, .700),
  Offset(.780, .700),
  Offset(.320, .805),
  Offset(.680, .805),
];

/// Coordonnées des parcelles du décor fourni, en proportions de 1376 × 768.
const villagePlots = <Offset>[
  // Remplir d'abord autour de la place pour les petites parties.
  Offset(.310, .445),
  Offset(.700, .445),
  Offset(.290, .635),
  Offset(.707, .625),
  Offset(.414, .340),
  Offset(.579, .340),
  Offset(.405, .770),
  Offset(.580, .770),
  Offset(.425, .205),
  Offset(.568, .205),
  Offset(.337, .245),
  Offset(.665, .245),
  Offset(.228, .335),
  Offset(.775, .335),
  Offset(.150, .615),
  Offset(.858, .615),
  Offset(.210, .740),
  Offset(.800, .740),
  Offset(.313, .856),
  Offset(.695, .850),
];

/// Recadrage d'affichage seulement : les PNG originaux restent intacts.
class HouseSprite extends StatelessWidget {
  const HouseSprite({super.key, required this.state, this.intense = false});
  final String state;
  final bool intense;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (intense) {
        return Image.asset(
          'assets/village/intense/house_$state.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        );
      }
      final geometry = houseSpriteGeometry[state]!;
      final scale = (size.maxWidth / geometry.visibleWidth).clamp(
        0.0,
        size.hasBoundedHeight
            ? size.maxHeight / geometry.visibleHeight
            : double.infinity,
      );
      final verticalSpace = size.hasBoundedHeight
          ? size.maxHeight - geometry.visibleHeight * scale
          : 0.0;
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left:
                  (size.maxWidth - geometry.visibleWidth * scale) / 2 -
                  geometry.left * scale,
              top: verticalSpace - geometry.top * scale,
              width: geometry.width * scale,
              height: geometry.height * scale,
              child: Image.asset(
                'assets/village/house_$state.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class VillageMap extends StatefulWidget {
  const VillageMap({
    super.key,
    required this.room,
    this.selfId,
    this.bubbleAuthors = const {},
    required this.onHouse,
    required this.onChat,
    this.displayHeight,
    this.animateGhosts = true,
    this.protectedPlayerId,
  });
  final Map<String, dynamic> room;
  final String? selfId;
  final Set<String> bubbleAuthors;
  final ValueChanged<Map<String, dynamic>> onHouse;
  final VoidCallback onChat;
  final double? displayHeight;
  final bool animateGhosts;
  final String? protectedPlayerId;
  @override
  State<VillageMap> createState() => _VillageMapState();
}

class _VillageMapState extends State<VillageMap> {
  bool get intense => widget.room['visual_pack'] == 'intense';
  List<Offset> get plots => intense ? intenseVillagePlots : villagePlots;
  final _transform = TransformationController();
  double _fit = 1;
  Size? _size;
  void _overview(Size size) {
    _fit = (size.width / 1376).clamp(.05, 1);
    final heightScale = size.height / 768;
    if (heightScale < _fit) _fit = heightScale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (size.width - 1376 * _fit) / 2,
        (size.height - 768 * _fit) / 2,
        0,
        1,
      )
      ..scaleByDouble(_fit, _fit, 1, 1);
  }

  void _initialView(Size size) {
    _overview(size);
    if (size.width / size.height < 1.3) {
      final scale = (size.height / 768).clamp(_fit, 2.0);
      _transform.value = Matrix4.identity()
        ..translateByDouble(
          (size.width - 1376 * scale) / 2,
          (size.height - 768 * scale) / 2,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    }
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    if (current * factor < _fit || current * factor > 2) return;
    final center = Offset(_size!.width / 2, _size!.height / 2);
    final point = _transform.toScene(center);
    final scale = current * factor;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - point.dx * scale,
        center.dy - point.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = (widget.room['players'] as List)
        .cast<Map<String, dynamic>>();
    final phase = widget.room['phase'];
    final night =
        (widget.room['game'] as Map?)?['is_night'] as bool? ??
        ['sleep', 'seer', 'wolves', 'witch'].contains(phase);
    final game = widget.room['game'] as Map?;
    final weather = VillageWeather.fromMap(
      intense
          ? {...?(game?['weather'] as Map?), 'kind': 'snow', 'rainbow': false}
          : game?['weather'] as Map?,
    );
    final alive = (game?['alive_ids'] as List?)?.cast<String>().toSet();
    final placed = [
      for (var i = 0; i < players.length && i < 20; i++)
        (
          player: players[i],
          slot: (players[i]['house_slot'] as int? ?? i).clamp(0, 19),
        ),
    ]..sort((a, b) => plots[a.slot].dy.compareTo(plots[b.slot].dy));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.cottage_outlined),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Village classique',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text('${players.length} maisons'),
            if (weather.raining || weather.rainbow)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  weather.storm
                      ? Icons.thunderstorm_outlined
                      : weather.raining
                      ? Icons.water_drop_outlined
                      : Icons.wb_sunny_outlined,
                  size: 18,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF101713),
              border: Border.all(color: const Color(0xFF97724B), width: 2),
            ),
            child: SizedBox(
              height:
                  widget.displayHeight ??
                  (MediaQuery.orientationOf(context) == Orientation.portrait
                      ? 350
                      : 420),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  if (_size != size) {
                    _size = size;
                    _initialView(size);
                  }
                  return Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: _fit,
                        maxScale: 2,
                        boundaryMargin: const EdgeInsets.all(250),
                        child: SizedBox(
                          width: 1376,
                          height: 768,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  intense
                                      ? 'assets/village/intense/map.png'
                                      : 'assets/village/map.jpg',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedContainer(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 1200),
                                    color: night
                                        ? const Color(0x99334279)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              for (final placement in placed)
                                Positioned(
                                  key: ValueKey<String>(
                                    placement.player['id'] as String,
                                  ),
                                  left: plots[placement.slot].dx * 1376 - 74,
                                  top: plots[placement.slot].dy * 768 - 140,
                                  width: 148,
                                  height: 170,
                                  child: _House(
                                    protected:
                                        placement.player['id'] ==
                                        widget.protectedPlayerId,
                                    intense: intense,
                                    player: placement.player,
                                    state:
                                        alive != null &&
                                            !alive.contains(
                                              placement.player['id'],
                                            )
                                        ? 'eliminated'
                                        : night
                                        ? 'night'
                                        : 'day',
                                    own:
                                        placement.player['id'] == widget.selfId,
                                    bubble: widget.bubbleAuthors.contains(
                                      placement.player['id'],
                                    ),
                                    onTap: () =>
                                        widget.onHouse(placement.player),
                                    onChat: widget.onChat,
                                  ),
                                ),
                              for (final placement in placed)
                                Positioned(
                                  left: plots[placement.slot].dx * 1376 - 80,
                                  top: plots[placement.slot].dy * 768 + 4,
                                  width: 160,
                                  child: _HouseLabel(
                                    player: placement.player,
                                    own:
                                        placement.player['id'] == widget.selfId,
                                    eliminated:
                                        alive != null &&
                                        !alive.contains(placement.player['id']),
                                    onTap: () =>
                                        widget.onHouse(placement.player),
                                  ),
                                ),
                              if (alive != null)
                                for (final placement in placed)
                                  if (!alive.contains(placement.player['id']))
                                    Positioned(
                                      left:
                                          plots[placement.slot].dx * 1376 - 28,
                                      top: plots[placement.slot].dy * 768 - 110,
                                      width: 56,
                                      height: 70,
                                      child: SpectatorGhost(
                                        key: ValueKey(
                                          'ghost-${placement.player['id']}',
                                        ),
                                        slot: placement.slot,
                                        name:
                                            placement.player['nickname']
                                                as String,
                                        animate: widget.animateGhosts,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(child: WeatherOverlay(weather: weather)),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Material(
                          color: const Color(0xE61A2029),
                          borderRadius: BorderRadius.circular(24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Vue d’ensemble',
                                onPressed: () => _overview(size),
                                icon: const Icon(Icons.fit_screen),
                              ),
                              IconButton(
                                tooltip: 'Agrandir le village',
                                onPressed: () => _zoom(1.5),
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                tooltip: 'Réduire le village',
                                onPressed: () => _zoom(1 / 1.5),
                                icon: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (players.isEmpty)
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'Les maisons apparaîtront à l’arrivée des joueurs.',
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pince pour zoomer, déplace le village et touche une maison. Une coupure conserve ta place pendant la partie.',
          style: TextStyle(fontSize: 12, color: Color(0xFFCCC6BB)),
        ),
      ],
    );
  }
}

class SpectatorGhost extends StatefulWidget {
  const SpectatorGhost({
    super.key,
    required this.slot,
    required this.name,
    this.animate = true,
  });
  final int slot;
  final String name;
  final bool animate;
  @override
  State<SpectatorGhost> createState() => _SpectatorGhostState();
}

class _SpectatorGhostState extends State<SpectatorGhost>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: Duration(seconds: 26 + widget.slot % 7),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Fantôme de ${widget.name} · Spectateur',
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final angle = _motion.value * math.pi * 2 + widget.slot;
          return Transform.translate(
            offset: Offset(math.sin(angle) * 38, math.cos(angle) * 16),
            child: child,
          );
        },
        child: Opacity(
          opacity: .72,
          child: Image.asset(
            'assets/village/spectator_ghost.png',
            fit: BoxFit.contain,
            cacheWidth: 128,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

class _House extends StatelessWidget {
  const _House({
    required this.player,
    required this.state,
    required this.own,
    required this.bubble,
    required this.onTap,
    required this.onChat,
    this.intense = false,
    this.protected = false,
  });
  final bool protected;
  final bool intense;
  final Map<String, dynamic> player;
  final String state;
  final bool own;
  final bool bubble;
  final VoidCallback onTap;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: Semantics(
          button: true,
          label:
              'Maison de ${player['nickname']}${own ? ', ta maison' : ''}, ${state == 'eliminated'
                  ? 'éliminé'
                  : player['connected'] == true
                  ? 'connecté'
                  : 'déconnecté'}',
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                SizedBox(
                  width: 142,
                  height: 142,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 800),
                    child: HouseSprite(
                      key: ValueKey('$intense-$state'),
                      state: state,
                      intense: intense,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (protected) Positioned.fill(child: GuardianAura(intense: intense)),
      if (bubble)
        Positioned(
          right: -2,
          top: -8,
          child: IconButton.filled(
            tooltip: 'Ouvrir la discussion autorisée',
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline, size: 25),
          ),
        ),
    ],
  );
}

class _HouseLabel extends StatelessWidget {
  const _HouseLabel({
    required this.player,
    required this.own,
    required this.eliminated,
    required this.onTap,
  });
  final Map<String, dynamic> player;
  final bool own;
  final bool eliminated;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xEA141C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: own ? const Color(0xFFEAC27C) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (player['connected'] != true)
            const Icon(Icons.wifi_off, size: 13, color: Colors.orange),
          if (eliminated)
            const Icon(Icons.visibility_off, size: 13, color: Colors.grey),
          Flexible(
            child: Text(
              '${player['nickname']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
