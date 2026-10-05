// Static data table for the player's army. Four unit types are available:
// Archer (starts unlocked, ranged, stationary), Knight (melee tank that
// marches to the defensive line), Mage (ranged AoE caster, stationary), and
// Dragon (flying, high-damage AoE breath, stationary). Knight/Mage/Dragon
// must be permanently unlocked from the Army screen (one-time coins/diamonds
// spend) before ArmyManager will ever spawn or deploy them; once unlocked,
// each has its own permanent level (1-3, like towers) that scales hp/damage,
// upgraded from the Army screen with coins. Deploying one manually mid-battle
// (troop bar) still costs coins on top of that, same as it always has.
import '../models/unit.dart';

class UnitLevelStat {
  final int hp;
  final int damage;

  /// Coins to reach THIS level from the previous one (0 for level 1, i.e.
  /// the stats a unit has the moment it's unlocked).
  final int upgradeCost;

  const UnitLevelStat({
    required this.hp,
    required this.damage,
    this.upgradeCost = 0,
  });
}

class UnitDef {
  final UnitType type;
  final String displayName;
  final String spriteName;
  final double speed;
  final double spawnIntervalSeconds;
  final bool isRanged;
  final double range;
  final bool isFlying;
  final bool isAoe;
  final bool healsNearby;

  /// Strikes enemies from a distance with an instant lightning bolt (Knight).
  final bool usesLightning;

  /// Panda Warrior only — fights with kung-fu, see Unit.usesKungFu.
  final bool usesKungFu;

  /// Elf Prince only — mind-controls Goblins / Orcs, see Unit.usesMindControl.
  final bool usesMindControl;

  /// Air-strike units (Phoenix): they fly out to this lane x and hover over
  /// the enemy zone, firing from there. 0 = stay in formation.
  final double advanceToX;
  final double advanceSpeed;

  /// Coins the player spends to manually deploy one of these via the
  /// battle-screen troop bar (StateProvider.deployReinforcement), on top of
  /// already being unlocked. Scales roughly with the unit's power, same as
  /// the auto-spawn cadence does via spawnIntervalSeconds.
  final int deployCost;

  /// One-time permanent unlock cost. Archer is 0/0 (available from the
  /// start); every other type needs coins (and sometimes diamonds) spent
  /// once from the Army screen before it ever appears in battle.
  final int unlockCost;
  final int unlockDiamondCost;

  /// Until this unit's own PNG exists, UnitComponent draws this existing
  /// sprite colour-washed with [fallbackTint] (ARGB int, 0 = none).
  final String? fallbackSprite;
  final int fallbackTint;

  /// Level 1..5 stats. Use [statAt] rather than indexing directly.
  final List<UnitLevelStat> levels;

  const UnitDef({
    required this.type,
    required this.displayName,
    required this.spriteName,
    required this.speed,
    required this.spawnIntervalSeconds,
    required this.deployCost,
    required this.levels,
    this.unlockCost = 0,
    this.unlockDiamondCost = 0,
    this.isRanged = false,
    this.range = 0,
    this.isFlying = false,
    this.isAoe = false,
    this.healsNearby = false,
    this.usesLightning = false,
    this.usesKungFu = false,
    this.usesMindControl = false,
    this.advanceToX = 0,
    this.advanceSpeed = 3.0,
    this.fallbackSprite,
    this.fallbackTint = 0,
  });

  int get maxLevel => levels.length;

  UnitLevelStat statAt(int level) => levels[(level - 1).clamp(0, levels.length - 1)];
}

class UnitData {
  UnitData._();

  static const Map<UnitType, UnitDef> defs = {
    UnitType.archer: UnitDef(
      type: UnitType.archer,
      displayName: 'Archer',
      spriteName: 'archer',
      // Stationary — archers hold their ground next to the castle and never
      // march toward enemies, so speed is 0.
      speed: 0.0,
      spawnIntervalSeconds: 2.0,
      isRanged: true,
      // Long range since they never move to close the distance themselves.
      range: 7.0,
      deployCost: 5, // TEST (orig 25)
      // Unlocked for free from the very start of the game.
      unlockCost: 0,
      levels: [
        UnitLevelStat(hp: 150, damage: 60),
        UnitLevelStat(hp: 220, damage: 90, upgradeCost: 10), // TEST (orig 150)
        UnitLevelStat(hp: 300, damage: 130, upgradeCost: 20), // TEST (orig 400)
        UnitLevelStat(hp: 400, damage: 180, upgradeCost: 30), // TEST (orig 900)
        UnitLevelStat(hp: 520, damage: 240, upgradeCost: 40), // TEST (orig 1800)
      ],
    ),
    UnitType.knight: UnitDef(
      type: UnitType.knight,
      displayName: 'Knight',
      spriteName: 'knight',
      // Tanky frontline that calls lightning down on enemies from a distance.
      usesLightning: true,
      range: 3.0,
      speed: 1.0,
      spawnIntervalSeconds: 3.0,
      deployCost: 5, // TEST (orig 40)
      unlockCost: 450, // raised
      levels: [
        UnitLevelStat(hp: 400, damage: 45),
        UnitLevelStat(hp: 600, damage: 70, upgradeCost: 10),
        UnitLevelStat(hp: 850, damage: 100, upgradeCost: 20),
        UnitLevelStat(hp: 1150, damage: 140, upgradeCost: 30),
        UnitLevelStat(hp: 1500, damage: 190, upgradeCost: 40),
      ],
    ),
    UnitType.mage: UnitDef(
      type: UnitType.mage,
      displayName: 'Mage',
      spriteName: 'mage',
      // Stationary caster, like the archer, but hits an area around its target.
      speed: 0.0,
      spawnIntervalSeconds: 4.0,
      isRanged: true,
      range: 6.0,
      isAoe: true,
      deployCost: 5, // TEST (orig 60)
      unlockCost: 900, // raised
      unlockDiamondCost: 15, // raised
      levels: [
        UnitLevelStat(hp: 120, damage: 70),
        UnitLevelStat(hp: 170, damage: 110, upgradeCost: 10),
        UnitLevelStat(hp: 230, damage: 160, upgradeCost: 20),
        UnitLevelStat(hp: 300, damage: 220, upgradeCost: 30),
        UnitLevelStat(hp: 400, damage: 300, upgradeCost: 40),
      ],
    ),
    UnitType.dragon: UnitDef(
      type: UnitType.dragon,
      displayName: 'Dragon',
      spriteName: 'good_dragon',
      // Hovers in place near the castle, breathing fire at range.
      speed: 0.0,
      spawnIntervalSeconds: 8.0,
      isRanged: true,
      range: 6.5,
      isFlying: true,
      isAoe: true,
      deployCost: 5, // TEST (orig 150)
      unlockCost: 2250, // raised
      unlockDiamondCost: 90, // raised
      levels: [
        UnitLevelStat(hp: 500, damage: 180),
        UnitLevelStat(hp: 750, damage: 260, upgradeCost: 10),
        UnitLevelStat(hp: 1050, damage: 380, upgradeCost: 20),
        UnitLevelStat(hp: 1450, damage: 520, upgradeCost: 30),
        UnitLevelStat(hp: 2000, damage: 700, upgradeCost: 40),
      ],
    ),
    UnitType.pandaWarrior: UnitDef(
      type: UnitType.pandaWarrior,
      displayName: 'Panda Warrior',
      // The Panda Warrior himself fights: flying kick, spin kick and palm
      // flurry (see UnitComponent._kungFuMove). No more summoned helper.
      spriteName: 'panda_warrior',
      usesKungFu: true,
      // Melee frontline, same marches-to-the-line behavior as Knight.
      speed: 1.0,
      spawnIntervalSeconds: 3.2,
      deployCost: 5, // TEST (orig 45)
      unlockCost: 675, // raised
      levels: [
        UnitLevelStat(hp: 300, damage: 65),
        UnitLevelStat(hp: 460, damage: 100, upgradeCost: 10),
        UnitLevelStat(hp: 650, damage: 145, upgradeCost: 20),
        UnitLevelStat(hp: 850, damage: 195, upgradeCost: 30),
        UnitLevelStat(hp: 1100, damage: 260, upgradeCost: 40),
      ],
    ),

    // ================= ELITE UNITS (Thunderstorm-ready) =================
    // Elf Prince: calls a barrage of fire down from the SKY onto the enemy
    // (same powers the old Holy Paladin had) AND casts MIND CONTROL: every
    // few seconds he turns nearby Goblins and Orcs against their own army,
    // so they fight on YOUR side for a while.
    UnitType.elfPrince: UnitDef(
      type: UnitType.elfPrince,
      displayName: 'Elf Prince',
      spriteName: 'elf_prince',
      usesMindControl: true,
      speed: 0.0,
      spawnIntervalSeconds: 5.0,
      // Calls fire down from the SKY onto enemies (see BattleEngine
      // _elfPrinceSkyFire): ranged, and the blast splashes on the neighbours.
      isRanged: true,
      range: 10.0, // reaches deep into the enemy half (was 6)
      isAoe: true,
      deployCost: 5, // TEST (orig 130)
      unlockCost: 3750, // raised
      unlockDiamondCost: 150, // raised
      // Until elf_prince.png is added, the elf archer art is shown with a
      // golden wash so the Prince still looks different from the Archer.
      fallbackSprite: 'archer',
      fallbackTint: 0xFFFFC107,
      levels: [
        UnitLevelStat(hp: 900, damage: 90),
        UnitLevelStat(hp: 1300, damage: 130, upgradeCost: 10),
        UnitLevelStat(hp: 1800, damage: 180, upgradeCost: 20),
        UnitLevelStat(hp: 2400, damage: 240, upgradeCost: 30),
        UnitLevelStat(hp: 3200, damage: 320, upgradeCost: 40),
      ],
    ),
    // Magician: keeps the whole squad alive. Every 2.5s it heals every
    // wounded ally nearby for 12% of their max HP (and itself), and it
    // smites enemies with holy bolts from range.
    UnitType.magician: UnitDef(
      type: UnitType.magician,
      displayName: 'Magician',
      spriteName: 'magician',
      speed: 0.0,
      spawnIntervalSeconds: 5.0,
      isRanged: true,
      range: 8.0, // magic balls land on the enemy side (was 5)
      healsNearby: true,
      deployCost: 5, // TEST (orig 90)
      unlockCost: 2700, // raised
      unlockDiamondCost: 105, // raised
      fallbackSprite: 'mage',
      fallbackTint: 0xFF69F0AE,
      levels: [
        UnitLevelStat(hp: 400, damage: 40),
        UnitLevelStat(hp: 550, damage: 55, upgradeCost: 10),
        UnitLevelStat(hp: 750, damage: 75, upgradeCost: 20),
        UnitLevelStat(hp: 1000, damage: 100, upgradeCost: 30),
        UnitLevelStat(hp: 1350, damage: 140, upgradeCost: 40),
      ],
    ),
    // Storm Phoenix: an immortal-looking fire bird. Flying, long range,
    // throws fireballs that explode on groups. Stronger than the Dragon.
    UnitType.phoenix: UnitDef(
      type: UnitType.phoenix,
      displayName: 'Storm Phoenix',
      spriteName: 'phoenix',
      speed: 0.0,
      spawnIntervalSeconds: 10.0,
      isRanged: true,
      range: 7.5,
      isFlying: true,
      isAoe: true,
      // Flies out over the enemy zone (x ~ 12 on the 0..20 lane) and
      // throws its fireballs from there.
      advanceToX: 12.0,
      advanceSpeed: 3.0,
      deployCost: 5, // TEST (orig 250)
      unlockCost: 7500, // raised
      unlockDiamondCost: 300, // raised
      fallbackSprite: 'good_dragon',
      fallbackTint: 0xFFFF7043,
      levels: [
        UnitLevelStat(hp: 700, damage: 260),
        UnitLevelStat(hp: 1000, damage: 380, upgradeCost: 10),
        UnitLevelStat(hp: 1400, damage: 540, upgradeCost: 20),
        UnitLevelStat(hp: 1900, damage: 750, upgradeCost: 30),
        UnitLevelStat(hp: 2600, damage: 1000, upgradeCost: 40),
      ],
    ),
  };

  static UnitDef defFor(UnitType type) => defs[type]!;

  // --- On-screen sprite sizes -------------------------------------------
  // Dragon and Phoenix are the big hitters, so they are drawn MUCH larger
  // than the 30px soldiers (UnitComponent + StormFx both read these so the
  // flame always leaves the mouth of the bigger sprite).
  static const double defaultRenderSize = 30.0;
  static const double kungFuRenderSize = 38.0;
  static const double dragonRenderSize = 110.0;
  static const double phoenixRenderSize = 84.0;

  static double renderSizeFor(UnitType type, {bool kungFu = false}) {
    switch (type) {
      case UnitType.dragon:
        return dragonRenderSize;
      case UnitType.phoenix:
        return phoenixRenderSize;
      default:
        return kungFu ? kungFuRenderSize : defaultRenderSize;
    }
  }

  /// How high the Phoenix hovers above its ground point (scales with size).
  static double hoverFor(UnitType type) =>
      type == UnitType.phoenix ? phoenixRenderSize * 0.55 : 0.0;

  // --- Knight squad slots -------------------------------------------------
  // Knights are special-cased vs the other 3 unit types: instead of one
  // shared "unlocked?" flag + one shared level, the player can own up to
  // [knightMaxSlots] separate Knights, purchased one at a time (in order,
  // slot 0 first) and each leveled up (1..UnitDef.knight.maxLevel)
  // independently of the others. Every unlocked slot puts one extra Knight
  // on the battlefield holding the front line (see ArmyManager) — so 5
  // unlocked slots means 5 Knights fighting at once, each potentially at a
  // different level. PlayerProgress.knightSlotLevels is the save-data for
  // this (0 = that slot not purchased yet).
  static const int knightMaxSlots = 5;

  /// How many soldiers of each type stand in the permanent formation (see
  /// ArmyManager). Knight is not listed: it stands one per purchased Knight
  /// slot. Change a number here to change the army size for that type.
  static const Map<UnitType, int> squadSize = {
    UnitType.pandaWarrior: 3, // elite: only 3
    UnitType.archer: 5,
    UnitType.mage: 2, // only 2 Mages, ever
    UnitType.dragon: 1,
    UnitType.elfPrince: 2,
    UnitType.magician: 1,
    UnitType.phoenix: 1,
  };

  static int squadSizeOf(UnitType type) => squadSize[type] ?? 0;

  // --- MP (mana) per unit type ------------------------------------------
  // Each unit type has its OWN MP bar. [mpCost] is the size of that bar and
  // is taken out of the castle's MP pool while it charges; [mpChargeSeconds]
  // is how long a full charge takes (stronger units cost more and charge
  // slower). Archer (the "bowman") = 50 MP.
  static const Map<UnitType, int> mpCost = {
    UnitType.archer: 50,
    UnitType.knight: 60,
    UnitType.magician: 60,
    UnitType.pandaWarrior: 70,
    UnitType.mage: 80,
    UnitType.elfPrince: 90,
    UnitType.phoenix: 110,
    UnitType.dragon: 120,
  };
  static const Map<UnitType, double> mpChargeSeconds = {
    UnitType.archer: 6.0,
    UnitType.knight: 7.0,
    UnitType.magician: 8.0,
    UnitType.pandaWarrior: 8.0,
    UnitType.mage: 9.0,
    UnitType.elfPrince: 11.0,
    UnitType.phoenix: 14.0,
    UnitType.dragon: 15.0,
  };

  static int mpCostOf(UnitType type) => mpCost[type] ?? 60;
  static double mpChargeSecondsOf(UnitType type) => mpChargeSeconds[type] ?? 8.0;

  /// Coins to unlock each Knight slot, in order. Slot 0 costs the same as
  /// the original single-Knight unlock (300); each slot after that costs
  /// more, same "keeps climbing" pattern as castle levels.
  static const List<int> knightSlotUnlockCosts = [20, 25, 30, 35, 40]; // TEST (orig 300, 450, 650, 900, 1200)
}
