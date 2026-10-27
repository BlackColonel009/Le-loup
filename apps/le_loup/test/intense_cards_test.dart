import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/cards/card_gallery.dart';
import 'package:le_loup/cards/classic_role.dart';

void main() {
  test(
    'Intense utilise les mêmes 17 rôles, avec 16 illustrations disponibles',
    () {
      expect(
        classicRoles.where((r) => RoleCardFront.hasIntense(r.id)).length,
        16,
      );
      expect(RoleCardFront.hasIntense('metamorph'), isTrue);
      expect(RoleCardFront.hasIntense('scapegoat'), isFalse);
    },
  );
  testWidgets('Les camps et pouvoirs Intense viennent des fiches communes', (
    tester,
  ) async {
    for (final id in [
      'metamorph',
      'angel',
      'white_wolf',
      'wolf_father',
      'alpha_wolf',
      'witch',
    ]) {
      final role = configuredRole(id);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 460,
              child: RoleCardFront(role: role, ambience: CardAmbience.intense),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Camp : ${role.camp}\n${role.summary}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
