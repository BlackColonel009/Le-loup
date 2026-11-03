import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/challenges/reward_claim_dialog.dart';

void main() {
  test('Stickers and portraits use the classic chest', () {
    expect(
      rewardChestTier([
        {'kind': 'sticker', 'id': 'classic_villager_joy'},
        {'kind': 'avatar', 'id': 'classic-villager'},
      ]),
      RewardChestTier.classic,
    );
  });
  test('Illustrated static border uses the epic chest', () {
    expect(
      rewardChestTier([
        {'kind': 'border', 'id': 'reward-village-hunter'},
      ]),
      RewardChestTier.epic,
    );
  });
  test('Animated border takes priority in a mixed batch', () {
    expect(
      rewardChestTier([
        {'kind': 'border', 'id': 'reward-village-hunter'},
        {'kind': 'border', 'id': 'amber'},
        {'kind': 'sticker', 'id': 'classic_villager_joy'},
      ]),
      RewardChestTier.premium,
    );
  });
  test('Unknown borders do not promote a chest', () {
    expect(
      rewardChestTier([
        {'kind': 'border', 'id': 'unknown'},
      ]),
      RewardChestTier.classic,
    );
  });
}
