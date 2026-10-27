import 'dart:math' as math;

/// État public d'ambiance ; aucune dépendance aux rôles ou aux actions secrètes.
class VillageWeather {
  const VillageWeather({
    this.kind = 'clear',
    this.seed = 0,
    this.night = 0,
    this.elapsedMs = 0,
    this.rainbow = false,
  });
  factory VillageWeather.fromMap(Map? value) => VillageWeather(
    kind: ['rain', 'storm', 'snow'].contains(value?['kind'])
        ? value!['kind'] as String
        : 'clear',
    seed: (value?['seed'] as num?)?.toInt() ?? 0,
    night: (value?['night'] as num?)?.toInt() ?? 0,
    elapsedMs: ((value?['elapsed_ms'] as num?)?.toInt() ?? 0).clamp(0, 1 << 40),
    rainbow: value?['rainbow'] == true,
  );
  final String kind;
  final int seed, night, elapsedMs;
  final bool rainbow;
  bool get raining => kind == 'rain' || kind == 'storm';
  bool get storm => kind == 'storm';
  bool get snowing => kind == 'snow';
  String get session => '$night:$seed:$kind';

  // Un éclair doux et espacé par tranche de 24 secondes, identique chez tous.
  int flashAt(int slot) => slot * 24000 + 4000 + ((seed + slot * 7919) % 9000);
  double lightningAt(int elapsed) {
    if (!storm) return 0;
    final age = elapsed - flashAt(elapsed ~/ 24000);
    if (age < 0 || age > 800) return 0;
    return .17 * math.sin(math.pi * age / 800);
  }

  int? thunderAt(int elapsed) {
    if (!storm) return null;
    final slot = elapsed ~/ 24000;
    final age = elapsed - flashAt(slot);
    return age >= 650 && age < 1800 ? slot : null;
  }
}
