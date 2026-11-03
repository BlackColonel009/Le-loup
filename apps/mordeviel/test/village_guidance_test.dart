import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/village_guidance.dart';
import 'package:mordeviel/village/village_navigation.dart';
import 'package:mordeviel/village/village_chat.dart';
import 'package:mordeviel/village/attention_surface.dart';
import 'package:mordeviel/services/immersion_preferences.dart';

Map<String, dynamic> room(String phase, {List messages = const []}) => {
  'phase': phase,
  'players': [
    {'id': 'a', 'nickname': 'Luna'},
    {'id': 'b', 'nickname': 'Noctis'},
  ],
  'game': {
    'phase_revision': 4,
    'night': 1,
    'chat_open': true,
    'day_messages': messages,
  },
};
void main() {
  test('Les repères privés ne dévoilent aucun canal aux autres joueurs', () {
    final r = room('wolves');
    for (final own in [
      {
        'id': 'a',
        'role': 'villager',
        'alive': true,
        'messages': [
          {'author': 'b', 'text': 'Secret'},
        ],
      },
      {
        'id': 'a',
        'is_pack': true,
        'alive': false,
        'messages': [
          {'author': 'b', 'text': 'Secret'},
        ],
      },
    ]) {
      final c = VillageChannel.resolve(r, own, isHost: false, connected: true);
      expect(c.kind, 'closed');
      expect(c.messages, isEmpty);
      expect(c.private, isFalse);
    }
    final c = VillageChannel.resolve(
      r,
      {'is_pack': true, 'alive': true, 'can_act': true},
      isHost: false,
      connected: true,
    );
    expect(c.kind, 'wolves');
    expect(c.writable, isTrue);
    final bond = {
      'alive': true,
      'bond_chat': {
        'kind': 'lovers',
        'remaining_ms': 60000,
        'open': true,
        'messages': [
          {'text': 'Secret'},
        ],
      },
    };
    expect(
      VillageChannel.resolve(
        room('lovers'),
        bond,
        isHost: false,
        connected: true,
        bondRemaining: 0,
      ).available,
      isFalse,
    );
    expect(
      VillageChannel.resolve(
        room('lovers'),
        bond,
        isHost: true,
        connected: true,
      ).available,
      isFalse,
    );
  });
  test('Le vote confirmé retire l’alerte et la pause ferme la saisie', () {
    final r = room('voting'),
        own = {
          'id': 'a',
          'alive': true,
          'can_vote': true,
          'vote_submitted': false,
        };
    var c = VillageChannel.resolve(r, own, isHost: false, connected: true);
    var g = VillageGuidance.resolve(
      r,
      own,
      isHost: false,
      connected: true,
      channel: c,
    );
    expect(g.attention, isTrue);
    expect(g.destination, VillageDestination.council);
    own['vote_submitted'] = true;
    g = VillageGuidance.resolve(
      r,
      own,
      isHost: false,
      connected: true,
      channel: c,
    );
    expect(g.attention, isFalse);
    expect(g.confirmed, isTrue);
    (r['game'] as Map)['paused'] = true;
    c = VillageChannel.resolve(r, own, isHost: false, connected: true);
    expect(c.writable, isFalse);
  });
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Navigation lisible et accès direct au scrutin à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var destination = VillageDestination.village;
      final data = room('voting');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => VillageNavigation(
                destination: destination,
                phase: 'voting',
                isHost: false,
                code: '123456',
                room: data,
                privateState: const {
                  'id': 'a',
                  'alive': true,
                  'can_vote': true,
                  'vote_submitted': false,
                },
                onSelect: (value) => update(() => destination = value),
                onCodex: () {},
                village: const Text('La carte'),
                chat: const Text('Messages du conseil'),
                actions: const Text('Bulletins disponibles'),
                preparation: const Text('Habitants'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('village-nav-village')), findsOneWidget);
      expect(find.byKey(const ValueKey('village-nav-actions')), findsOneWidget);
      await tester.tap(find.text('Voter maintenant'));
      await tester.pumpAndSettle();
      expect(destination, VillageDestination.council);
      expect(find.text('Bulletins disponibles'), findsOneWidget);
      await tester.tap(find.text('Discussion'));
      await tester.pumpAndSettle();
      expect(find.text('Messages du conseil'), findsOneWidget);
      await tester.tap(find.text('Voter maintenant'));
      await tester.pumpAndSettle();
      expect(find.text('Bulletins disponibles'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('village-nav-village')));
      await tester.pumpAndSettle();
      expect(find.text('La carte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Nouveaux messages signalés puis lus sans ouvrir le chat automatiquement',
    (tester) async {
      var data = room('day'), destination = VillageDestination.village;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return VillageNavigation(
                  destination: destination,
                  phase: 'day',
                  isHost: false,
                  code: '123456',
                  room: data,
                  privateState: const {'id': 'a', 'alive': true},
                  selfId: 'a',
                  onSelect: (value) => set(() => destination = value),
                  onCodex: () {},
                  village: const Text('La carte'),
                  chat: const Text('Les messages'),
                  actions: const Text('Actions'),
                  preparation: const Text('Habitants'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(
        () => data = room(
          'day',
          messages: [
            {'author': 'b', 'text': 'Qui est suspect ?'},
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(destination, VillageDestination.village);
      final button = find.byKey(const ValueKey('village-nav-chat'));
      final surface = find
          .ancestor(of: button, matching: find.byType(AttentionSurface))
          .first;
      expect(tester.widget<AttentionSurface>(surface).active, isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Les messages'), findsOneWidget);
      expect(tester.widget<AttentionSurface>(surface).active, isFalse);
    },
  );
  testWidgets(
    'Les surbrillances s’arrêtent et respectent les mouvements réduits',
    (tester) async {
      ImmersionPreferences.instance.lightEffects = true;
      addTearDown(() => ImmersionPreferences.instance.lightEffects = false);
      await tester.pumpWidget(
        const MaterialApp(
          home: AttentionSurface(
            active: true,
            token: 'vote',
            child: Text('Voter'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'La meute garde ses réactions et le conseil son brouillon au clavier',
    (tester) async {
      var height = 600.0;
      final r = room('wolves');
      final own = {'id': 'a', 'is_pack': true, 'alive': true, 'can_act': true};
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: height,
            child: VillageNavigation(
              destination: VillageDestination.chat,
              phase: 'wolves',
              isHost: false,
              code: '123456',
              room: r,
              privateState: own,
              selfId: 'a',
              onSelect: (_) {},
              onCodex: () {},
              village: const Text('Carte'),
              actions: const Text('Action'),
              preparation: const Text('Habitants'),
              chat: VillageChat(
                room: {
                  ...r,
                  'features': ['house_reactions'],
                },
                privateState: own,
                isHost: false,
                connected: true,
                onSend: (_, _, _, {replyTo}) {},
                fullPage: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stickers'), findsOneWidget);
      expect(find.text('Réagir sur ma maison'), findsOneWidget);
      final field = find.byKey(const ValueKey('village-chat-input'));
      await tester.enterText(field, 'Mon soupçon');
      await tester.pump();
      final before = tester.state(field);
      height = 235;
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(tester.state(field), same(before));
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.widget<TextField>(field).controller!.text, 'Mon soupçon');
      expect(tester.takeException(), isNull);
    },
  );
}
