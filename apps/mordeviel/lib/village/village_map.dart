import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:local_host/local_host.dart';
import 'weather_overlay.dart';
import 'house_sprite_geometry.dart';
import 'house_contour_light.dart';
import 'guardian_aura.dart';
import '../content/content_image.dart';
import '../content/pack_store.dart';
import 'horror_ambience.dart';
import 'village_camera.dart';
import 'village_life.dart';
import '../services/immersion_preferences.dart';
import 'house_reaction.dart';

/// The Intense terrain has more room than the classic canvas. House sprites
/// keep their readable size while the distance between plots increases.
const intenseVillageCanvasSize = Size(3072, 2048);
const classicVillageCanvasSize = Size(1376, 768);
// Ground anchors measured on the 1536 × 1024 artwork, not a regular grid.
// Four wide western plots each accommodate a second home for players 17–20.
const horrorVillagePlots = <Offset>[
  Offset(.345, .553),
  Offset(.610, .553),
  Offset(.175, .553),
  Offset(.805, .553),
  Offset(.345, .390),
  Offset(.605, .390),
  Offset(.345, .694),
  Offset(.625, .694),
  Offset(.200, .390),
  Offset(.795, .390),
  Offset(.160, .694),
  Offset(.830, .694),
  Offset(.345, .273),
  Offset(.610, .273),
  Offset(.210, .273),
  Offset(.785, .273),
  Offset(.415, .553),
  Offset(.415, .390),
  Offset(.415, .694),
  Offset(.415, .273),
];

/// Ground anchors surveyed on map_v3's 1536 × 1024 artwork. The snowy
/// clearings narrow and shift between rows; a regular grid lands on the roads.
/// Keep the slot order: existing players retain their place around the square.
const intenseVillagePlots = <Offset>[
  Offset(577 / 1536, 553 / 1024),
  Offset(965 / 1536, 553 / 1024),
  Offset(275 / 1536, 553 / 1024),
  Offset(1280 / 1536, 553 / 1024),
  Offset(581 / 1536, 398 / 1024),
  Offset(959 / 1536, 398 / 1024),
  Offset(573 / 1536, 718 / 1024),
  Offset(974 / 1536, 718 / 1024),
  Offset(287 / 1536, 398 / 1024),
  Offset(1268 / 1536, 398 / 1024),
  Offset(266 / 1536, 718 / 1024),
  Offset(1288 / 1536, 718 / 1024),
  Offset(584 / 1536, 256 / 1024),
  Offset(954 / 1536, 256 / 1024),
  Offset(300 / 1536, 256 / 1024),
  Offset(1257 / 1536, 256 / 1024),
  Offset(569 / 1536, 884 / 1024),
  Offset(977 / 1536, 884 / 1024),
  Offset(281 / 1536, 884 / 1024),
  Offset(1266 / 1536, 884 / 1024),
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
  const HouseSprite({
    super.key,
    required this.state,
    this.intense = false,
    this.horror = false,
  });
  final String state;
  final bool intense;
  final bool horror;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (horror) {
        return ListenableBuilder(
          listenable: PackStore.instance,
          builder: (context, _) {
            final asset = 'assets/village/horror/house_$state.png';
            final downloaded = PackStore.instance.pathFor(asset) != null;
            return _framed(
              size,
              downloaded
                  ? horrorHouseSpriteGeometry[state]!
                  : houseSpriteGeometry[state]!,
              downloaded
                  ? ContentImage(asset, fit: BoxFit.fill)
                  : Image.asset(
                      'assets/village/house_$state.png',
                      fit: BoxFit.fill,
                    ),
            );
          },
        );
      }
      return _framed(
        size,
        intense
            ? intenseHouseSpriteGeometry[state]!
            : houseSpriteGeometry[state]!,
        Image.asset(
          'assets/village/${intense ? 'intense/' : ''}house_$state.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      );
    },
  );

  Widget _framed(
    BoxConstraints size,
    HouseSpriteGeometry geometry,
    Widget image,
  ) {
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
            child: image,
          ),
        ],
      ),
    );
  }
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
    this.onPointerActivity,
    this.reactions = const [],
    this.speakers = const {},
    this.spyingHouses = const {},
  });
  final Map<String, dynamic> room;
  final String? selfId;
  final Set<String> bubbleAuthors;
  final ValueChanged<Map<String, dynamic>> onHouse;
  final VoidCallback onChat;
  final double? displayHeight;
  final bool animateGhosts;
  final String? protectedPlayerId;

  /// Suspend the enclosing page's scroll while fingers manipulate the map.
  final ValueChanged<bool>? onPointerActivity;
  final List<Map> reactions;
  final Set<String> speakers;
  final Set<String> spyingHouses;
  @override
  State<VillageMap> createState() => _VillageMapState();
}

class _VillageMapState extends State<VillageMap> with WidgetsBindingObserver {
  double get _spriteExtent => horror
      ? 190
      : intense
      ? 238
      : 112;
  double get _houseWidth => _spriteExtent + 6;
  double get _labelWidth => horror
      ? 196
      : intense
      ? 260
      : 136;
  bool get horror => widget.room['visual_pack'] == 'horror';
  bool get intense =>
      ['intense', 'horror'].contains(widget.room['visual_pack']);
  Size get _world =>
      intense ? intenseVillageCanvasSize : classicVillageCanvasSize;
  List<Offset> get plots => horror
      ? horrorVillagePlots
      : intense
      ? intenseVillagePlots
      : villagePlots;
  VillageCameraController? _camera;
  Size? _size;
  String? _viewIdentity;
  int _cameraRevision = 0;
  final _pointers = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _pointer(int pointer, bool down) {
    final wasActive = _pointers.isNotEmpty;
    down ? _pointers.add(pointer) : _pointers.remove(pointer);
    if (wasActive != _pointers.isNotEmpty) {
      widget.onPointerActivity?.call(_pointers.isNotEmpty);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pointers.isNotEmpty) {
      _pointers.clear();
      widget.onPointerActivity?.call(false);
    }
  }

  void _layoutCamera(Size size) {
    final identity = '${widget.room['code']}:${widget.room['visual_pack']}';
    if (_camera != null && _size == size && _viewIdentity == identity) return;
    final old = _camera;
    _camera = old != null && _viewIdentity == identity
        ? old.forViewport(size)
        : VillageCameraController(
            world: _world,
            viewport: size,
            initialScale: math.max(
              math.max(size.width / _world.width, size.height / _world.height),
              50 / _spriteExtent,
            ),
          );
    _size = size;
    _viewIdentity = identity;
    _cameraRevision++;
    old?.dispose();
  }

  void _moveCamera(VoidCallback command) {
    setState(() {
      // Recreate the gesture state to stop any previous inertial movement.
      _cameraRevision++;
      command();
    });
  }

  void _selectHouse(Map<String, dynamic> player) {
    ImmersionPreferences.instance.touch();
    widget.onHouse(player);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    if (_pointers.isNotEmpty) {
      final release = widget.onPointerActivity;
      WidgetsBinding.instance.addPostFrameCallback((_) => release?.call(false));
    }
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
      intense && !horror
          ? {...?(game?['weather'] as Map?), 'kind': 'snow', 'rainbow': false}
          : game?['weather'] as Map?,
    );
    final alive = (game?['alive_ids'] as List?)?.cast<String>().toSet();
    final placed = [
      for (var i = 0; i < players.length && i < 20; i++)
        (
          player: {...players[i], 'mayor': game?['mayor'] == players[i]['id']},
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
            Expanded(
              child: Text(
                horror
                    ? 'Village Horreur'
                    : intense
                    ? 'Village Intense Premium'
                    : 'Village classique',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                  if (size.isEmpty || !size.isFinite) {
                    return const SizedBox.shrink();
                  }
                  _layoutCamera(size);
                  return Listener(
                    onPointerDown: (event) => _pointer(event.pointer, true),
                    onPointerUp: (event) => _pointer(event.pointer, false),
                    onPointerCancel: (event) => _pointer(event.pointer, false),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          key: ValueKey(_cameraRevision),
                          transformationController: _camera,
                          constrained: false,
                          minScale: _camera!.minScale,
                          maxScale: _camera!.maxScale,
                          // The controller bounds translation per axis, including
                          // letterboxed overview, without forcing a minimum cover.
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: SizedBox(
                            width: _world.width,
                            height: _world.height,
                            child: RepaintBoundary(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ContentImage(
                                      horror
                                          ? 'assets/village/horror/map.png'
                                          : intense
                                          ? 'assets/village/intense/map_v3.png'
                                          : 'assets/village/map.jpg',
                                      fallbackAsset: intense
                                          ? 'assets/village/intense/map_v3.png'
                                          : 'assets/village/map.jpg',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedContainer(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? Duration.zero
                                            : const Duration(
                                                milliseconds: 1200,
                                              ),
                                        color: night
                                            ? horror
                                                  ? const Color(0x552C1D40)
                                                  : const Color(0x99334279)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  for (final placement in placed)
                                    Positioned(
                                      key: ValueKey<String>(
                                        placement.player['id'] as String,
                                      ),
                                      left:
                                          plots[placement.slot].dx *
                                              _world.width -
                                          _houseWidth / 2,
                                      top:
                                          plots[placement.slot].dy *
                                              _world.height -
                                          _spriteExtent,
                                      width: _houseWidth,
                                      height: _spriteExtent + 28,
                                      child: _House(
                                        spying:
                                            game?['phase'] == 'wolves' &&
                                            widget.spyingHouses.contains(
                                              placement.player['id'],
                                            ),
                                        marked:
                                            (game?['marked_houses'] as List? ??
                                                    const [])
                                                .contains(
                                                  placement.player['id'],
                                                ),
                                        paused: game?['paused'] == true,
                                        spriteExtent: _spriteExtent,
                                        ready:
                                            game == null &&
                                            widget.room['phase'] == 'lobby' &&
                                            placement.player['ready'] == true,
                                        protected:
                                            placement.player['id'] ==
                                            widget.protectedPlayerId,
                                        intense: intense,
                                        horror: horror,
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
                                            placement.player['id'] ==
                                            widget.selfId,
                                        bubble: widget.bubbleAuthors.contains(
                                          placement.player['id'],
                                        ),
                                        onTap: () =>
                                            _selectHouse(placement.player),
                                        onChat: widget.onChat,
                                      ),
                                    ),
                                  for (final placement in placed)
                                    Positioned(
                                      left:
                                          plots[placement.slot].dx *
                                              _world.width -
                                          _labelWidth / 2,
                                      top:
                                          plots[placement.slot].dy *
                                              _world.height +
                                          4,
                                      width: _labelWidth,
                                      child: _HouseLabel(
                                        intense: intense,
                                        player: placement.player,
                                        own:
                                            placement.player['id'] ==
                                            widget.selfId,
                                        eliminated:
                                            alive != null &&
                                            !alive.contains(
                                              placement.player['id'],
                                            ),
                                        onTap: () =>
                                            _selectHouse(placement.player),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: VillageLife(
                                      night: night,
                                      paused: game?['paused'] == true,
                                      plots: [
                                        for (final p in placed)
                                          if (alive == null ||
                                              alive.contains(p.player['id']))
                                            (plots[p.slot], _spriteExtent),
                                      ],
                                    ),
                                  ),
                                  if (alive != null)
                                    for (final placement in placed)
                                      if (!alive.contains(
                                        placement.player['id'],
                                      ))
                                        Positioned(
                                          left:
                                              plots[placement.slot].dx *
                                                  _world.width -
                                              (intense ? 40 : 28),
                                          top:
                                              plots[placement.slot].dy *
                                                  _world.height -
                                              _spriteExtent * .78,
                                          width: intense ? 80 : 56,
                                          height: intense ? 100 : 70,
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
                                  for (final placement in placed)
                                    if (widget.speakers.contains(
                                      placement.player['id'],
                                    ))
                                      Positioned(
                                        left:
                                            plots[placement.slot].dx *
                                                _world.width -
                                            16,
                                        top:
                                            plots[placement.slot].dy *
                                                _world.height -
                                            _spriteExtent -
                                            40,
                                        child: const Icon(
                                          Icons.graphic_eq,
                                          color: Color(0xFF68E7B3),
                                          size: 32,
                                        ),
                                      ),
                                  for (final reaction in widget.reactions)
                                    if (placed.any(
                                      (p) =>
                                          p.player['id'] == reaction['author'],
                                    ))
                                      Positioned(
                                        left:
                                            plots[placed
                                                        .firstWhere(
                                                          (p) =>
                                                              p.player['id'] ==
                                                              reaction['author'],
                                                        )
                                                        .slot]
                                                    .dx *
                                                _world.width -
                                            _spriteExtent * .35,
                                        top:
                                            plots[placed
                                                        .firstWhere(
                                                          (p) =>
                                                              p.player['id'] ==
                                                              reaction['author'],
                                                        )
                                                        .slot]
                                                    .dy *
                                                _world.height -
                                            _spriteExtent * 1.45,
                                        width: _spriteExtent * .7,
                                        height: _spriteExtent * .7,
                                        child: HouseReaction(
                                          key: ValueKey(reaction['id']),
                                          reaction: reaction,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: WeatherOverlay(weather: weather),
                          ),
                        ),
                        if (horror)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: HorrorAmbience(
                                camera: _camera,
                                world: _world,
                                night: night,
                                seed: game?['night'] as int? ?? 0,
                                paused: game?['paused'] == true,
                              ),
                            ),
                          ),
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
                                  onPressed: () =>
                                      _moveCamera(_camera!.overview),
                                  icon: const Icon(Icons.fit_screen),
                                ),
                                IconButton(
                                  tooltip: 'Agrandir le village',
                                  onPressed: () =>
                                      _moveCamera(() => _camera!.zoomBy(1.5)),
                                  icon: const Icon(Icons.add),
                                ),
                                IconButton(
                                  tooltip: 'Réduire le village',
                                  onPressed: () => _moveCamera(
                                    () => _camera!.zoomBy(1 / 1.5),
                                  ),
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
                    ),
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
    required this.spriteExtent,
    required this.player,
    required this.state,
    required this.own,
    required this.bubble,
    required this.onTap,
    required this.onChat,
    this.intense = false,
    this.horror = false,
    this.protected = false,
    this.ready = false,
    this.paused = false,
    this.marked = false,
    this.spying = false,
  });
  final bool ready;
  final bool paused;
  final bool marked;
  final bool spying;
  final double spriteExtent;
  final bool protected;
  final bool intense;
  final bool horror;
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
      if (ready || state == 'eliminated')
        Positioned(
          left: intense ? -44 : -28,
          right: intense ? -44 : -28,
          top: spriteExtent - (intense ? 32 : 24),
          height: intense ? 64 : 48,
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey(
                'house-glow-${player['id']}-${ready ? 'ready' : 'eliminated'}',
              ),
              painter: _HouseGroundGlow(
                ready ? const Color(0xFF45D879) : const Color(0xFFEF4545),
              ),
            ),
          ),
        ),
      Positioned.fill(
        child: Semantics(
          button: true,
          label:
              'Maison de ${player['nickname']}${own ? ', ta maison' : ''}${ready ? ', prêt' : ''}, ${state == 'eliminated'
                  ? 'éliminé'
                  : player['connected'] == true
                  ? 'connecté'
                  : 'déconnecté'}',
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                SizedBox(
                  width: spriteExtent,
                  height: spriteExtent,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 800),
                    child: intense && !horror
                        ? HouseContourLight(
                            key: ValueKey('intense-$state'),
                            state: state,
                            phase: (player['house_slot'] as int? ?? 0) * .173,
                            paused: paused,
                            child: HouseSprite(state: state, intense: true),
                          )
                        : HouseSprite(
                            key: ValueKey(
                              '${horror
                                  ? 'horror'
                                  : intense
                                  ? 'intense'
                                  : 'classic'}-$state',
                            ),
                            state: state,
                            intense: intense,
                            horror: horror,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (protected) Positioned.fill(child: GuardianAura(intense: intense)),
      if (spying)
        const Positioned(
          left: 0,
          right: 0,
          top: -20,
          child: IgnorePointer(child: Center(child: _PeekingEye())),
        ),
      if (marked)
        Positioned(
          left: 0,
          top: 8,
          child: Tooltip(
            message: 'Cette maison porte la marque du Veilleur',
            child: Icon(
              Icons.visibility,
              key: ValueKey('marked-house-${player['id']}'),
              color: const Color(0xFFD9B8EB),
              size: intense ? 34 : 22,
            ),
          ),
        ),
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

class _PeekingEye extends StatefulWidget {
  const _PeekingEye();
  @override
  State<_PeekingEye> createState() => _PeekingEyeState();
}

class _PeekingEyeState extends State<_PeekingEye>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'La Petite Fille observe la meute',
    child: CustomPaint(
      size: const Size(38, 23),
      painter: _PeekingEyePainter(_motion),
    ),
  );
}

class _PeekingEyePainter extends CustomPainter {
  _PeekingEyePainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = motion.value * 3;
    final phase = sweep % 1;
    final blinkAt = const [.24, .63, .91][sweep.floor() % 3];
    final blink = ((phase - blinkAt).abs() / .044).clamp(.08, 1.0);
    final lookRight = Curves.easeInOut.transform(
      ((phase - .19) / .25).clamp(0.0, 1.0),
    );
    final lookLeft = Curves.easeInOut.transform(
      ((phase - .66) / .27).clamp(0.0, 1.0),
    );
    final center = size.center(Offset.zero);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, blink);
    final eye = Path()
      ..moveTo(-17, 0)
      ..quadraticBezierTo(0, -19, 17, 0)
      ..quadraticBezierTo(0, 19, -17, 0)
      ..close();
    canvas.drawPath(eye, Paint()..color = const Color(0xFF252031));
    canvas.drawPath(
      eye,
      Paint()
        ..color = const Color(0xFFF6D499)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final pupil = Offset(7 * (2 * (lookRight - lookLeft) - 1), 0);
    canvas.drawCircle(pupil, 5, Paint()..color = const Color(0xFFFFC16F));
    canvas.drawCircle(pupil, 2.4, Paint()..color = const Color(0xFF252031));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PeekingEyePainter oldDelegate) =>
      oldDelegate.motion != motion;
}

class _HouseGroundGlow extends CustomPainter {
  const _HouseGroundGlow(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .8),
          color.withValues(alpha: .55),
          color.withValues(alpha: 0),
        ],
        stops: const [0, .65, 1],
      ).createShader(const Rect.fromLTRB(-1, -1, 1, 1));
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HouseGroundGlow old) => old.color != color;
}

class _HouseLabel extends StatelessWidget {
  const _HouseLabel({
    required this.player,
    required this.own,
    required this.eliminated,
    required this.onTap,
    this.intense = false,
  });
  final Map<String, dynamic> player;
  final bool own;
  final bool eliminated;
  final bool intense;
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
          if (player['mayor'] == true)
            const Icon(
              Icons.workspace_premium,
              size: 18,
              color: Color(0xFFEAC27C),
            ),
          if (player['connected'] != true)
            const Icon(Icons.wifi_off, size: 13, color: Colors.orange),
          if (eliminated)
            const Icon(Icons.visibility_off, size: 13, color: Colors.grey),
          Flexible(
            child: Text(
              '${player['nickname']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: intense ? 20 : 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
