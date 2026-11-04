import 'package:flutter/material.dart';

enum RewardChestTier { classic, epic, premium }

Color rewardChestLight(RewardChestTier tier) => switch (tier) {
  RewardChestTier.classic => const Color(0xFFFFD995),
  RewardChestTier.epic => const Color(0xFFD1A1FF),
  RewardChestTier.premium => const Color(0xFF79EBF4),
};

RewardChestTier? explicitChallengeTier(Map challenge) =>
    switch (challenge['chest_tier']) {
      'classic' => RewardChestTier.classic,
      'epic' => RewardChestTier.epic,
      'premium' => RewardChestTier.premium,
      _ => null,
    };

String challengeTierLabel(Map challenge) =>
    switch (explicitChallengeTier(challenge) ?? RewardChestTier.classic) {
      RewardChestTier.classic => 'Coffre classique · Facile',
      RewardChestTier.epic => 'Coffre épique · Moyen',
      RewardChestTier.premium => 'Coffre premium · Élevé',
    };
