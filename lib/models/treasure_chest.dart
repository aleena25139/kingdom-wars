// Model for a treasure chest reward. ChestTier determines the reward range;
// actual random-roll logic lives in game_logic (kept out of the model so
// this stays a plain data class).

enum ChestTier { common, rare, legendary }

class ChestRewards {
  final int coins;
  final int diamonds;
  final List<String> unitCardIds;
  final List<String> towerCardIds;

  const ChestRewards({
    required this.coins,
    required this.diamonds,
    this.unitCardIds = const [],
    this.towerCardIds = const [],
  });
}

class TreasureChest {
  final String id;
  final ChestTier tier;
  final DateTime availableAt;
  bool opened;
  ChestRewards? rewards; // populated once opened

  TreasureChest({
    required this.id,
    required this.tier,
    required this.availableAt,
    this.opened = false,
    this.rewards,
  });

  bool isReadyAt(DateTime now) => !opened && !now.isBefore(availableAt);

  String get spriteName {
    switch (tier) {
      case ChestTier.common:
        return 'chest_common';
      case ChestTier.rare:
        return 'chest_rare';
      case ChestTier.legendary:
        return 'chest_legendary';
    }
  }
}
