import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/profile/avatar_border.dart';
import 'package:mordeviel/profile/border_gallery.dart';

void main() {
  testWidgets(
    'Le reflet tourne puis reste fixe en mouvement réduit et en arrière-plan',
    (tester) async {
      Widget scene({bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: SizedBox.square(
              dimension: 120,
              child: AnimatedAvatarBorder(
                border: avatarBorder('creator-gold')!,
                child: const CircleAvatar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(scene(reduced: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 780.0]) {
    testWidgets(
      'Les huit bordures prémium restent verrouillées à $width, aperçu sans achat',
      (tester) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final selections = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AvatarBorderGallery(
                  borders: [
                    for (final b in avatarBorderCatalog)
                      if (b['creator_only'] != true)
                        {...b, 'locked': b['free'] != true},
                  ],
                  current: const {'border_id': 'none'},
                  canEdit: true,
                  onSelect: (b) => selections.add(b['id'] as String),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bordure prémium.'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('border-rainbow')),
        );
        await tester.tap(find.byKey(const ValueKey('border-rainbow')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('pas encore déblocable'), findsOneWidget);
        expect(selections, isEmpty);
        await tester.tap(find.text('Fermer'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('border-none')));
        await tester.tap(find.byKey(const ValueKey('border-none')));
        expect(selections, ['none']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
