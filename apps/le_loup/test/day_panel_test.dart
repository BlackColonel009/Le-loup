import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/night_panel.dart';

Widget screen({
  required bool host,
  required Map<String, dynamic> game,
  Map<String, dynamic>? private,
  SendNightAction? onAction,
  void Function(int)? onVote,
  bool showDayChat = true,
  ValueChanged<bool>? onChat,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: NightPanel(
        showDayChat: showDayChat,
        onChat: onChat,
        room: {
          'players': [
            {'id': 'a', 'nickname': 'Alice'},
            {'id': 'b', 'nickname': 'Basile'},
          ],
          'game': game,
        },
        privateState: private,
        isHost: host,
        connected: true,
        onStart: (_) {},
        onAdvance: () {},
        onPause: () {},
        onResume: () {},
        onVote: onVote,
        onAction:
            onAction ??
            (action, revision, {target, save, kill, text, targets}) {},
      ),
    ),
  ),
);

Map<String, dynamic> state(String phase) => {
  'phase': phase,
  'phase_revision': 4,
  'night': 1,
  'announcement': 'Le village vote.',
  'remaining_ms': 60000,
  'paused': false,
  'closed': false,
  'alive_ids': ['a', 'b'],
  'deaths': [],
  'chat_open': true,
  'day_messages': [],
  'votes_received': 0,
};

void main() {
  testWidgets('Le conseil conserve le contrôle du chat séparé', (tester) async {
    bool? opened;
    await tester.pumpWidget(
      screen(
        host: true,
        game: state('day'),
        showDayChat: false,
        onChat: (value) => opened = value,
      ),
    );
    expect(find.text('Discussion générale'), findsNothing);
    await tester.ensureVisible(find.text('Autoriser le chat général'));
    await tester.tap(find.byType(SwitchListTile));
    expect(opened, false);
  });
  testWidgets('Le MDJ ouvre un vote chronométré', (tester) async {
    int? seconds;
    await tester.pumpWidget(
      screen(
        host: true,
        game: state('day'),
        onVote: (value) => seconds = value,
      ),
    );
    await tester.ensureVisible(find.text('Ouvrir le vote du village'));
    await tester.tap(find.text('Ouvrir le vote du village'));
    expect(seconds, 120);
  });
  testWidgets('Un vote blanc est transmis distinctement de l’abstention', (
    tester,
  ) async {
    var sent = false;
    await tester.pumpWidget(
      screen(
        host: false,
        game: state('voting'),
        private: {
          'id': 'a',
          'alive': true,
          'phase_revision': 4,
          'can_vote': true,
          'can_act': false,
        },
        onAction: (action, revision, {target, save, kill, text, targets}) {
          expect(action, 'vote.cast');
          expect(target, isNull);
          expect(revision, 4);
          sent = true;
        },
      ),
    );
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vote blanc').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmer mon vote'));
    await tester.tap(find.text('Confirmer mon vote'));
    expect(sent, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Un éliminé ne reçoit ni saisie ni commande de vote', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        host: false,
        game: state('voting'),
        private: {
          'id': 'a',
          'alive': false,
          'phase_revision': 4,
          'can_vote': false,
          'can_act': false,
        },
      ),
    );
    expect(find.text('Confirmer mon vote'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Tu es éliminé'), findsOneWidget);
  });
}
