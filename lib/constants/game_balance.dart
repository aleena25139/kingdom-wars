// Global balance constants that aren't specific to a single unit/tower/enemy
// type. Tower/enemy/unit/level *data tables* live in their own files
// (tower_data.dart, enemy_data.dart, unit_data.dart, level_data.dart) — this
// file holds economy, castle progression, and generic tuning knobs.
import 'dart:math';

class CastleLevelStat {
  final int level;
  final int hp;
  final double spawnIntervalSeconds;
  final int upgradeCost; // coins required to reach this level from previous
  const CastleLevelStat({
    required this.level,
    required this.hp,
    required this.spawnIntervalSeconds,
    required this.upgradeCost,
  });
}

class GameBalance {
  GameBalance._();

  // --- Economy ---
  static const int startingCoins = 300;
  static const int startingDiamonds = 0;
  static const int coinsPerEnemyKillBase = 5;
  static const int coinsPerWaveClearBase = 50;

  // --- Battle ---
  static const int totalWavesPerLevel = 20;
  static const int bossWaveInterval = 5; // every 5th wave is a boss wave
  static const double enemyStatScalePerWave = 0.10; // +10% per wave (endless)
  static const List<double> battleSpeedOptions = [1.0, 2.0, 3.0];
  // Player archers and skeleton archers both fire this same visible arrow;
  // a bit faster than a tower's shot (12.0) since unit-vs-unit engagement
  // ranges are much shorter, so a slower arrow would look like it lingers.
  static const double arrowProjectileSpeed = 14.0;

  // --- Player army ---
  // The player's army is a small, fixed-size defensive squad rather than an
  // ever-growing horde — never more than this many units (any unlocked type,
  // combined) are alive on the field at once (auto-spawn and manual deploys
  // both stop once this cap is hit).
  static const int maxArmySquad = 20;

  // --- Grid (tower placement) ---
  static const int towerGridColumns = 6;
  static const int towerGridRows = 4;
  static const double towerGridCellSize = 64.0;

  // --- Treasure chests ---
  static const Duration freeChestInterval = Duration(hours: 4);

  // --- Castle progression (HP + spawn rate per level) ---
  // Endless, Grow-Castle-style: no top level. Every stat is computed from a
  // formula instead of a fixed table, so level 200 works exactly like level
  // 20 — it just costs and hits proportionally harder.
  static const int _castleBaseHp = 2000;
  static const double _castleHpGrowth = 1.35; // +35% HP per level
  static const double _castleBaseSpawnInterval = 5.0; // seconds, at level 1
  static const double _castleSpawnDecreasePerLevel = 0.12; // gets a bit faster each level
  static const double _castleMinSpawnInterval = 1.0; // never faster than this
  static const int _castleCostBase = 400;
  static const double _castleCostGrowth = 1.32; // +32% cost per level

  // --- MP (blue mana bar) ---
  // The castle's MP pool starts FULL (200 at castle level 1; every castle
  // upgrade adds a few points: +15 for level 2, +17 for level 3 ... so
  // maxMpFor(L) = 200 + (L-1)*(L+13)). If the pool ever reaches ZERO the
  // battle is lost, same as losing the castle.
  static const int baseMaxMp = 200;
  // The pool refills slowly on its own: an empty pool would take this long
  // to fill again, whatever the castle level.
  static const double mpRegenSeconds = 100.0;
  // Every unit type has its own small MP bar (cost + charge time are in
  // UnitData.mpCostOf / mpChargeSecondsOf). Charging it takes that much MP
  // out of the castle pool. A full unit bar can be spent on a boost: every
  // soldier of that type attacks at [boostAttackSpeed]x speed for
  // [boostSeconds].
  static const double boostSeconds = 5.0;
  static const double boostAttackSpeed = 2.0;

  // --- Endless score ---
  static const int scorePerCoinReward = 10; // kill points = enemy coinReward x this
  static const int endlessWaveBonusScore = 100; // x wave number, on reaching a new wave

  static int mpBonusForLevel(int level) => level <= 1 ? 0 : 13 + 2 * (level - 1);

  static int maxMpFor(int level) {
    final l = level < 1 ? 1 : level;
    return baseMaxMp + (l - 1) * (l + 13);
  }

  static CastleLevelStat castleStatFor(int level) {
    final safeLevel = level < 1 ? 1 : level;
    final hp = (_castleBaseHp * pow(_castleHpGrowth, safeLevel - 1)).round();
    final spawnInterval = max(
      _castleMinSpawnInterval,
      _castleBaseSpawnInterval - _castleSpawnDecreasePerLevel * (safeLevel - 1),
    );
    final upgradeCost =
        safeLevel <= 1 ? 0 : (_castleCostBase * pow(_castleCostGrowth, safeLevel - 1)).round();
    return CastleLevelStat(
      level: safeLevel,
      hp: hp,
      spawnIntervalSeconds: spawnInterval,
      upgradeCost: upgradeCost,
    );
  }
}
