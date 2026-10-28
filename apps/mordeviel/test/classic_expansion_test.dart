import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/classic_role.dart';

void main() {
  test(
    'La collection compte 18 cartes, avec 13 fiches supplémentaires distinctes',
    () {
      expect(classicRoles.length, 18);
      expect(additionalClassicRoles.length, 13);
      expect(classicRoles.map((role) => role.id).toSet().length, 18);
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
    'Les 18 rôles intégrés sont jouables avec les bons camps',
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
      expect(playableClassicRoles.length, 18);
      expect(configuredRole('idiot').camp, 'Village');
      expect(configuredRole('white_wolf').camp, 'Solitaire');
      expect(configuredRole('metamorph').details, contains('deux cartes'));
      expect(configuredRole('angel').details, contains('Simple Villageois'));
    },
  );
}
