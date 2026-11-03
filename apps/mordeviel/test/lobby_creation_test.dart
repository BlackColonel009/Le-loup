import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/lobby_native.dart';
import 'package:mordeviel/village/village_navigation.dart';

void main() {
  testWidgets('Créer un salon local affiche le village et ses commandes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.classic,
        home: const LocalLobbyScreen(
          initialNickname: 'Le MDJ',
          autoStart: true,
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.byType(VillageNavigation).evaluate().isNotEmpty) break;
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(VillageNavigation), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });
}
