import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/cards/classic_role.dart';

void main() {
  test(
    'La collection compte 17 cartes, avec 12 fiches supplémentaires distinctes',
    () {
      expect(classicRoles.length, 17);
      expect(additionalClassicRoles.length, 12);
      expect(classicRoles.map((role) => role.id).toSet().length, 17);
      for (final role in additionalClassicRoles) {
        expect(File(role.asset).existsSync(), isTrue, reason: role.name);
        expect(
          File(role.asset).lengthSync(),
          greaterThan(10000),
          reason: role.name,
        );
        expect(role.summary, isNotEmpty);
        expect(role.details, isNotEmpty);
      }
    },
  );
  test(
    'Les 17 rôles intégrés sont jouables avec les bons camps',
    () {
      expect(coreClassicRoles.map((role) => role.id).toSet(), {
        'villager',
        'werewolf',
        'seer',
        'witch',
        'hunter',
      });
      expect(playableClassicRoles.every((role) => role.implemented), isTrue);
      expect(additionalClassicRoles.every((role) => role.implemented), isTrue);
      expect(playableClassicRoles.length, 17);
      expect(configuredRole('idiot').camp, 'Village');
      expect(configuredRole('white_wolf').camp, 'Solitaire');
      expect(configuredRole('metamorph').details, contains('deux cartes'));
      expect(configuredRole('angel').details, contains('Simple Villageois'));
    },
  );
}
