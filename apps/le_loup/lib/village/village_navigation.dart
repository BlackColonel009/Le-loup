import 'package:flutter/material.dart';
import '../design/game_theme.dart';

enum VillageDestination { village, council, chat, actions, preparation }

class VillageNavigation extends StatelessWidget {
  const VillageNavigation({
    super.key,
    required this.destination,
    required this.phase,
    required this.isHost,
    required this.code,
    required this.onSelect,
    required this.onCodex,
    required this.village,
    required this.chat,
    required this.actions,
    required this.preparation,
    this.banner,
    this.audioControl,
  });
  final VillageDestination destination;
  final String phase, code;
  final bool isHost;
  final ValueChanged<VillageDestination> onSelect;
  final VoidCallback onCodex;
  final Widget village, chat, actions, preparation;
  final Widget? banner, audioControl;

  static const titles = {
    VillageDestination.village: 'Le village',
    VillageDestination.council: 'Conseil du village',
    VillageDestination.chat: 'Discussions',
    VillageDestination.actions: 'Actions de la partie',
    VillageDestination.preparation: 'Habitants et préparation',
  };
  static const icons = [
    Icons.cottage_outlined,
    Icons.groups_outlined,
    Icons.chat_bubble_outline,
    Icons.nights_stay_outlined,
    Icons.tune,
  ];

  @override
  Widget build(BuildContext context) {
    final day = ['day', 'voting', 'vote_result'].contains(phase);
    final ballot = ['voting', 'vote_result'].contains(phase);
    final council = destination == VillageDestination.council;
    Widget content;
    if (council && day) {
      content = DefaultTabController(
        key: ValueKey(ballot),
        length: 2,
        initialIndex: ballot ? 1 : 0,
        child: Column(
          children: [
            const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Color(0xFF354038),
                borderRadius: BorderRadius.all(Radius.circular(14)),
                border: Border.fromBorderSide(
                  BorderSide(color: GameTheme.gold, width: .7),
                ),
              ),
              labelColor: GameTheme.ivory,
              tabs: [
                Tab(icon: Icon(Icons.forum_outlined), text: 'Discussion'),
                Tab(
                  icon: Icon(Icons.how_to_vote_outlined),
                  text: 'Réunion et vote',
                ),
              ],
            ),
            Expanded(child: TabBarView(children: [chat, actions])),
          ],
        ),
      );
    } else if (council && ['hunter', 'scapegoat', 'ended'].contains(phase)) {
      content = actions;
    } else if (council) {
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.nights_stay_outlined,
                size: 56,
                color: Color(0xFFE1BB80),
              ),
              const SizedBox(height: 20),
              Text(
                'Le conseil se réunit au lever du jour',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Pendant la nuit, suivez les appels du maître du jeu.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => onSelect(VillageDestination.actions),
                child: const Text('Voir la phase en cours'),
              ),
            ],
          ),
        ),
      );
    } else {
      content = switch (destination) {
        VillageDestination.village => village,
        VillageDestination.chat => chat,
        VillageDestination.preparation => preparation,
        _ => actions,
      };
    }
    final menu = PopupMenuButton<VillageDestination>(
      tooltip: 'Menu du village',
      initialValue: destination,
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final item in VillageDestination.values)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                Icon(
                  icons[item.index],
                  size: 22,
                  color: item == destination ? GameTheme.gold : GameTheme.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item == VillageDestination.actions && isHost
                        ? 'Table du MDJ'
                        : titles[item]!,
                  ),
                ),
                if (item == destination)
                  const Icon(Icons.check, size: 18, color: GameTheme.gold),
              ],
            ),
          ),
      ],
      child:
          destination != VillageDestination.village &&
              MediaQuery.sizeOf(context).width < 440
          ? const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.menu))
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu),
                  SizedBox(width: 8),
                  Text('Menu'),
                  Icon(Icons.expand_more),
                ],
              ),
            ),
    );
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[destination]!,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Salon $code · ${phase == 'lobby'
                            ? 'Préparation'
                            : day
                            ? 'Jour'
                            : phase == 'ended'
                            ? 'Partie terminée'
                            : 'Nuit'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCodex,
                  tooltip: 'Codex et règles',
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                ?audioControl,
                if (destination != VillageDestination.village) menu,
              ],
            ),
          ),
          ?banner,
          Expanded(
            child: destination == VillageDestination.village
                ? Stack(
                    children: [
                      Positioned.fill(child: content),
                      Positioned(
                        top: 72,
                        right: 28,
                        child: Material(
                          elevation: 0,
                          color: GameTheme.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: GameTheme.gold,
                              width: .7,
                            ),
                          ),
                          child: menu,
                        ),
                      ),
                    ],
                  )
                : content,
          ),
        ],
      ),
    );
  }
}
