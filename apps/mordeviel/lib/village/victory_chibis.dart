import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ending_data.dart';
import '../content/content_image.dart';

const victoryChibiAssets = <String, String>{
  'villager': 'villageois',
  'werewolf': 'loup-garou',
  'seer': 'voyante',
  'witch': 'sorciere',
  'hunter': 'chasseur',
  'little_girl': 'petite-fille',
  'metamorph': 'metamorphe',
  'cupid': 'cupidon',
  'guardian': 'salvateur',
  'elder': 'ancien',
  'scapegoat': 'bouc-emissaire',
  'alpha_wolf': 'alpha',
  'white_wolf': 'loup-blanc',
  'wolf_father': 'pere-des-loups',
  'idiot': 'idiot-du-village',
  'piper': 'joueur-de-flute',
  'angel': 'ange',
  'sisters': 'deux-soeurs',
  'mayor': 'maire',
  'sulfuron': 'sulfuron',
};

class VictoryFigure {
  const VictoryFigure(this.id, this.role, this.name, this.survived);
  final String id, role, name;
  final bool? survived;
  String get asset =>
      'assets/chibis/victory/${victoryChibiAssets[role]}-v1.png';
}

/// Winning players only, using final roles (including swaps and infections).
List<VictoryFigure> victoryFigures(Map game, List players) {
  if (game['winner'] == 'draw') return [];
  final winners = (game['winner_ids'] as List? ?? []).toSet();
  final alive = (game['alive_ids'] as List?)?.toSet();
  final roles = game['revealed_roles'] as Map? ?? {};
  final result = <VictoryFigure>[];
  final sisters = <Map>[];
  for (final player in players.whereType<Map>()) {
    final id = player['id'];
    if (!winners.contains(id)) continue;
    final role = roles[id];
    if (!victoryChibiAssets.containsKey(role)) continue;
    if (role == 'sisters') {
      sisters.add(player);
      continue;
    }
    result.add(
      VictoryFigure(
        id.toString(),
        role as String,
        player['nickname'] as String? ?? 'Joueur',
        alive?.contains(id),
      ),
    );
  }
  // The two sisters share one illustrated asset; never display the pair twice.
  if (sisters.isNotEmpty) {
    result.add(
      VictoryFigure(
        'sisters',
        'sisters',
        sisters.map((p) => p['nickname'] ?? 'Sœur').join(' & '),
        alive == null ? null : sisters.any((p) => alive.contains(p['id'])),
      ),
    );
  }
  if (result.isEmpty) {
    final role = gameEndings[game['winner']]?.role;
    if (role != null && victoryChibiAssets.containsKey(role)) {
      result.add(VictoryFigure('camp', role, 'Camp vainqueur', null));
    }
  }
  return result;
}

/// Sources face right. Left-side figures face left; the centre stays unchanged.
bool mirrorVictoryFigure(int index, int count) => index < (count - 1) / 2;

class VictoryChibiGroup extends StatelessWidget {
  const VictoryChibiGroup({super.key, required this.figures});
  final List<VictoryFigure> figures;
  @override
  Widget build(BuildContext context) {
    final front = figures.where((p) => p.survived != false).toList();
    final back = figures.where((p) => p.survived == false).toList();
    // With no survivors (e.g. a special victory), keep the winners prominent.
    if (front.isEmpty) {
      front.addAll(back);
      back.clear();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = math.max(front.length, back.length);
        final width = math.max(constraints.maxWidth, slots * 120.0);
        return SizedBox(
          height: 310,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: 310,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < back.length; i++)
                    Positioned(
                      left: width * (i + .5) / back.length - 54,
                      top: 0,
                      width: 108,
                      height: 192,
                      child: Opacity(
                        opacity: .55,
                        child: _figure(back[i], i, back.length),
                      ),
                    ),
                  for (var i = 0; i < front.length; i++)
                    Positioned(
                      left: width * (i + .5) / front.length - 72,
                      bottom: 0,
                      width: 144,
                      height: back.isEmpty ? 300 : 250,
                      child: _figure(front[i], i, front.length),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _figure(VictoryFigure figure, int index, int count) => Semantics(
    label:
        '${figure.name}${figure.survived == true
            ? ', survivant'
            : figure.survived == false
            ? ', membre du camp vainqueur éliminé'
            : ''}',
    child: Column(
      children: [
        Expanded(
          child: Transform.flip(
            key: ValueKey('victory-facing-${figure.id}'),
            flipX: mirrorVictoryFigure(index, count),
            child: ContentImage(
              figure.asset,
              fit: BoxFit.contain,
              cacheWidth: 512,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          figure.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    ),
  );
}
