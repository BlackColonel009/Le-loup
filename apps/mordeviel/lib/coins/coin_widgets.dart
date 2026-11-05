import 'package:flutter/material.dart';

const coinName = 'Lunes d’or';
const coinGold = Color(0xFFEAC76C);

String compactCoins(int amount) {
  if (amount < 1000) return '$amount';
  final unit = amount >= 999950 ? 1000000 : 1000;
  final number = (amount / unit).toStringAsFixed(amount % unit == 0 ? 0 : 1);
  return '${number.replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ',')}${unit == 1000 ? 'K' : 'M'}';
}

int coinsAtImpact(int amount, int milliseconds, List<int> impacts) {
  if (impacts.isEmpty) return 0;
  final hits = impacts.where((t) => t <= milliseconds).length;
  return amount * hits ~/ impacts.length;
}

// The supplied artwork is kept intact. Crop its white margins in the widget,
// then mask only its outer silhouette; all coin displays share this asset.
const goldMoonAsset = 'assets/rewards/gold_moon.webp';
const bronzeMoonAsset = 'assets/rewards/bronze_moon.webp';

enum MoonMetal { gold, bronze }

class CoinToken extends StatelessWidget {
  const CoinToken({super.key, this.size = 28, this.metal = MoonMetal.gold});
  final double size;
  final MoonMetal metal;
  @override
  Widget build(BuildContext context) => Semantics(
    label: metal == MoonMetal.gold
        ? 'Pièce Lune d’or, tête de loup'
        : 'Pièce Lune bronze, tête de loup',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: FittedBox(
          fit: BoxFit.fill,
          child: ClipRect(
            child: Align(
              alignment: Alignment(0, metal == MoonMetal.gold ? -.025 : 0),
              widthFactor: metal == MoonMetal.gold ? 1 : 1570 / 1792,
              heightFactor: metal == MoonMetal.gold ? 1840 / 2400 : 1636 / 2400,
              child: Image.asset(
                metal == MoonMetal.gold ? goldMoonAsset : bronzeMoonAsset,
                width: 448,
                height: 600,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(32, 512),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CoinBalanceCard extends StatelessWidget {
  const CoinBalanceCard({
    super.key,
    required this.balance,
    this.bronzeBalance,
    required this.onTap,
  });
  final int? balance;
  final int? bronzeBalance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF282419),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: coinGold.withValues(alpha: .4)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CoinToken(size: 54),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balance == null ? '—' : '$balance',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: coinGold,
                        ),
                      ),
                      const Text(
                        'Lunes d’or',
                        style: TextStyle(color: coinGold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ma bourse · gains et achats',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: coinGold),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const CoinToken(size: 32, metal: MoonMetal.bronze),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${bronzeBalance ?? '—'} Lunes bronze',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'À venir',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
