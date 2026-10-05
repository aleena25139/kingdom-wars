// Static data table for towers: base cost to build, and damage/range/special
// values at each of the 3 upgrade levels. Runtime Tower instances (tower.dart)
// only store {type, level}; everything else is looked up here.
import '../models/tower.dart';
import '../models/projectile.dart';

class TowerLevelStat {
  final int damage;
  final double range; // world units
  final double attackIntervalSeconds;
  final ProjectileEffect effect;
  final double effectMagnitude; // splash radius / slow factor / burn dmg-per-tick
  final double effectDuration; // slow/burn duration in seconds
  final int chainCount; // tesla only
  final int upgradeCost; // coins to reach THIS level from the previous one (0 for level 1)

  const TowerLevelStat({
    required this.damage,
    required this.range,
    required this.attackIntervalSeconds,
    this.effect = ProjectileEffect.none,
    this.effectMagnitude = 0,
    this.effectDuration = 0,
    this.chainCount = 0,
    this.upgradeCost = 0,
  });
}

class TowerDef {
  final TowerType type;
  final String displayName;
  final int buildCost;
  final String spriteBaseName; // sprite registry key without _lvlN suffix
  final String projectileSpriteName;
  final List<TowerLevelStat> levels; // index 0 = level 1, index 1 = level 2, index 2 = level 3

  /// Castle level at which this tower becomes available to build. The
  /// bottom tower bar only shows a tower once PlayerProgress.castleLevel
  /// reaches this — it doesn't just dim it, it isn't shown at all, so the
  /// bar only ever displays towers the player can actually use right now.
  final int unlockCastleLevel;

  const TowerDef({
    required this.type,
    required this.displayName,
    required this.buildCost,
    required this.spriteBaseName,
    required this.projectileSpriteName,
    required this.levels,
    this.unlockCastleLevel = 1,
  });

  TowerLevelStat statAt(int level) => levels[(level - 1).clamp(0, levels.length - 1)];

  String spriteNameAt(int level) =>
      level == 1 ? spriteBaseName : '${spriteBaseName}_lvl$level';
}

class TowerData {
  TowerData._();

  static const Map<TowerType, TowerDef> defs = {
    TowerType.cannon: TowerDef(
      type: TowerType.cannon,
      displayName: 'Cannon',
      buildCost: 50,
      spriteBaseName: 'tower_cannon',
      projectileSpriteName: 'projectile_cannonball',
      unlockCastleLevel: 1,
      levels: [
        TowerLevelStat(
          damage: 50,
          range: 3.0,
          attackIntervalSeconds: 1.2,
          effect: ProjectileEffect.splash,
          effectMagnitude: 0.8, // splash radius
        ),
        TowerLevelStat(
          damage: 90,
          range: 3.2,
          attackIntervalSeconds: 1.1,
          effect: ProjectileEffect.splash,
          effectMagnitude: 1.0,
          upgradeCost: 120,
        ),
        TowerLevelStat(
          damage: 150,
          range: 3.5,
          attackIntervalSeconds: 1.0,
          effect: ProjectileEffect.splash,
          effectMagnitude: 1.3,
          upgradeCost: 300,
        ),
      ],
    ),
    TowerType.archer: TowerDef(
      type: TowerType.archer,
      displayName: 'Archer Tower',
      buildCost: 40,
      spriteBaseName: 'tower_archer',
      projectileSpriteName: 'projectile_arrow',
      unlockCastleLevel: 1,
      levels: [
        TowerLevelStat(damage: 30, range: 4.5, attackIntervalSeconds: 0.5),
        TowerLevelStat(damage: 55, range: 4.8, attackIntervalSeconds: 0.45, upgradeCost: 90),
        TowerLevelStat(damage: 90, range: 5.2, attackIntervalSeconds: 0.4, upgradeCost: 220),
      ],
    ),
    TowerType.mage: TowerDef(
      type: TowerType.mage,
      displayName: 'Mage Tower',
      buildCost: 80,
      spriteBaseName: 'tower_mage',
      projectileSpriteName: 'projectile_bolt',
      unlockCastleLevel: 3,
      levels: [
        TowerLevelStat(
          damage: 100,
          range: 3.5,
          attackIntervalSeconds: 1.5,
          effect: ProjectileEffect.slow,
          effectMagnitude: 0.35, // 35% slow
          effectDuration: 2.0,
        ),
        TowerLevelStat(
          damage: 160,
          range: 3.7,
          attackIntervalSeconds: 1.4,
          effect: ProjectileEffect.slow,
          effectMagnitude: 0.45,
          effectDuration: 2.5,
          upgradeCost: 180,
        ),
        TowerLevelStat(
          damage: 240,
          range: 4.0,
          attackIntervalSeconds: 1.3,
          effect: ProjectileEffect.slow,
          effectMagnitude: 0.55,
          effectDuration: 3.0,
          upgradeCost: 400,
        ),
      ],
    ),
    TowerType.flamethrower: TowerDef(
      type: TowerType.flamethrower,
      displayName: 'Flamethrower',
      buildCost: 70,
      spriteBaseName: 'tower_flamethrower',
      projectileSpriteName: 'projectile_fireball',
      unlockCastleLevel: 2,
      levels: [
        TowerLevelStat(
          damage: 20,
          range: 2.5,
          attackIntervalSeconds: 0.3,
          effect: ProjectileEffect.burn,
          effectMagnitude: 10, // burn dmg per tick
          effectDuration: 3.0,
        ),
        TowerLevelStat(
          damage: 35,
          range: 2.7,
          attackIntervalSeconds: 0.28,
          effect: ProjectileEffect.burn,
          effectMagnitude: 18,
          effectDuration: 3.5,
          upgradeCost: 150,
        ),
        TowerLevelStat(
          damage: 55,
          range: 3.0,
          attackIntervalSeconds: 0.25,
          effect: ProjectileEffect.burn,
          effectMagnitude: 28,
          effectDuration: 4.0,
          upgradeCost: 350,
        ),
      ],
    ),
    TowerType.sniper: TowerDef(
      type: TowerType.sniper,
      displayName: 'Sniper Tower',
      buildCost: 100,
      spriteBaseName: 'tower_sniper',
      projectileSpriteName: 'projectile_bolt',
      unlockCastleLevel: 4,
      levels: [
        TowerLevelStat(damage: 200, range: 7.0, attackIntervalSeconds: 2.5),
        TowerLevelStat(damage: 340, range: 7.5, attackIntervalSeconds: 2.3, upgradeCost: 250),
        TowerLevelStat(damage: 520, range: 8.0, attackIntervalSeconds: 2.0, upgradeCost: 550),
      ],
    ),
    TowerType.tesla: TowerDef(
      type: TowerType.tesla,
      displayName: 'Tesla Tower',
      buildCost: 120,
      spriteBaseName: 'tower_tesla',
      projectileSpriteName: 'projectile_bolt',
      unlockCastleLevel: 5,
      levels: [
        TowerLevelStat(
          damage: 80,
          range: 3.2,
          attackIntervalSeconds: 1.0,
          effect: ProjectileEffect.chain,
          chainCount: 3,
        ),
        TowerLevelStat(
          damage: 130,
          range: 3.4,
          attackIntervalSeconds: 0.9,
          effect: ProjectileEffect.chain,
          chainCount: 4,
          upgradeCost: 280,
        ),
        TowerLevelStat(
          damage: 200,
          range: 3.6,
          attackIntervalSeconds: 0.8,
          effect: ProjectileEffect.chain,
          chainCount: 5,
          upgradeCost: 600,
        ),
      ],
    ),
  };

  static TowerDef defFor(TowerType type) => defs[type]!;
}
