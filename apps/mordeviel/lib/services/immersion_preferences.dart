import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImmersionPreferences extends ChangeNotifier {
  static final instance = ImmersionPreferences();
  bool vibrations = true, cardSounds = true, lightEffects = false;
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    vibrations = prefs.getBool('immersion_vibrations') ?? true;
    cardSounds = prefs.getBool('immersion_card_sounds') ?? true;
    lightEffects = prefs.getBool('immersion_light_effects') ?? false;
    notifyListeners();
  }

  Future<void> configure({bool? haptics, bool? sounds, bool? light}) async {
    vibrations = haptics ?? vibrations;
    cardSounds = sounds ?? cardSounds;
    lightEffects = light ?? lightEffects;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersion_vibrations', vibrations);
    await prefs.setBool('immersion_card_sounds', cardSounds);
    await prefs.setBool('immersion_light_effects', lightEffects);
  }

  bool reduced(BuildContext context) =>
      lightEffects ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  void touch({bool strong = false}) {
    if (!vibrations) return;
    (strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick())
        .catchError((Object _) {});
  }
}
