import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/cards/game_codex.dart';
import 'package:mordeviel/cards/codex_grimoire.dart';

const room = <String, dynamic>{
  'deck': {'villager': 2, 'werewolf': 1, 'seer': 1, 'witch': 0, 'hunter': 0},
  'seer_camp_only': true,
};
void main() {
  test('La variante Voyante remplace le texte standard', () {
    expect(configuredRole('seer').summary, contains('rôle exact'));
    expect(
      configuredRole('seer', seerCampOnly: true).summary,
      contains('le camp'),
    );
    expect(configuredRole('witch', seerCampOnly: true).id, 'witch');
  });
  test('Le grimoire lit la composition sans aucune attribution privée', () {
    final chapters = codexChapters({
      ...room,
      'assignments': {'JoueurConfidentiel123': 'witch'},
    });
    expect(chapters.any((c) => c.title == 'Voyante × 1'), isTrue);
    expect(chapters.any((c) => c.title.contains('Sorcière')), isFalse);
    expect(
      chapters.map((c) => c.text).join(),
      isNot(contains('JoueurConfidentiel123')),
    );
  });
  testWidgets(
    'Le sommaire ouvre les règles de la Voyante choisies par le MDJ',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGameCodex(context, room),
                child: const Text('Codex'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();
      expect(find.byType(CodexGrimoire), findsOneWidget);
      await tester.tap(find.text('Sommaire'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voyante × 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voyante × 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('seul le camp est révélé'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Fermer le Codex'));
      await tester.pumpAndSettle();
      expect(find.byType(CodexGrimoire), findsNothing);
    },
  );
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'Les pages gardent tout leur texte à $size et en grands caractères',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final words = List.generate(130, (i) => 'repère$i').join(' ');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: CodexGrimoire(
              chapters: [CodexChapter('Les secrets du village', words)],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fragments = <int, String>{};
        for (var turn = 0; turn < 100; turn++) {
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            final key = text.key;
            if (key is ValueKey<String> &&
                key.value.startsWith('codex-leaf-')) {
              fragments[int.parse(key.value.substring(11))] = text.data!;
              final render = tester.renderObject<RenderBox>(find.byKey(key));
              final painter = TextPainter(
                text: TextSpan(text: text.data, style: text.style),
                textScaler: const TextScaler.linear(1.6),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: render.size.width);
              expect(painter.height, lessThanOrEqualTo(render.size.height + 1));
              painter.dispose();
            }
          }
          final next = tester.widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Page suivante',
            ),
          );
          if (next.onPressed == null) break;
          await tester.tap(find.byTooltip('Page suivante'));
          await tester.pumpAndSettle();
        }
        final keys = fragments.keys.toList()..sort();
        expect(
          keys
              .map((i) => fragments[i]!)
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' '),
          words,
        );
        expect(
          find.textContaining(size.width > size.height ? 'Pages ' : 'Page '),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
