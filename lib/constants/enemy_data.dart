// Static data table for enemy units. There's only one enemy type now: a
// small ("tiny") skeleton that walks steadily from the spawn edge toward the
// player castle. WaveManager/BattleEngine read this to spawn Enemy instances
// (enemy.dart), scaling hp/damage up per-wave via statMultiplier.
import '../models/enemy.dart';

class EnemyDef {
  final EnemyType type;
  final String displayName;
  final String spriteName;
  final int hp;
  final int damage;
  final double speed;
  final double spawnIntervalSeconds; // baseline spawn cadence for this type
  final bool isFlying;
  final bool isBoss;
  final bool isRanged; // true for bow-armed enemies like the skeleton archer
  final double range; // 0 for melee; engagement distance for ranged enemies
  final EnemyAttackKind attackKind;
  final int coinReward;
  final double meleeReach; // how close a melee enemy must get to hit
  final double attackInterval; // seconds between its own attacks
  final double aggroRange; // how far away it notices and chases your units
  final double cleaveRadius; // claw sweep radius (0 = single target)
  final double cleaveFraction; // fraction of damage dealt to sweep victims
  // If this enemy's own PNG isn't in assets yet, EnemyComponent draws this
  // existing sprite instead, tinted with [fallbackTint] (ARGB int, 0 = none),
  // so the enemy is never invisible while art is still being generated.
  final String? fallbackSprite;
  final int fallbackTint;

  const EnemyDef({
    required this.type,
    required this.displayName,
    required this.spriteName,
    required this.hp,
    required this.damage,
    required this.speed,
    required this.spawnIntervalSeconds,
    this.isFlying = false,
    this.isBoss = false,
    this.isRanged = false,
    this.range = 0,
    this.attackKind = EnemyAttackKind.melee,
    required this.coinReward,
    this.meleeReach = 1.0,
    this.attackInterval = 1.0,
    this.aggroRange = 3.0,
    this.cleaveRadius = 0,
    this.cleaveFraction = 0.6,
    this.fallbackSprite,
    this.fallbackTint = 0,
  });
}

class EnemyData {
  EnemyData._();

  static const Map<EnemyType, EnemyDef> defs = {
    EnemyType.skeleton: EnemyDef(
      type: EnemyType.skeleton,
      displayName: 'Skeleton',
      spriteName: 'skeleton',
      hp: 80,
      damage: 20,
      speed: 1.0,
      spawnIntervalSeconds: 2.0,
      coinReward: 4,
    ),
    // Bow-armed skeleton: fewer bones behind the draw, so it's squishier
    // than the melee skeleton, but it engages from range instead of having
    // to close the distance, and hits a bit harder per shot.
    EnemyType.skeletonArcher: EnemyDef(
      type: EnemyType.skeletonArcher,
      displayName: 'Skeleton Archer',
      spriteName: 'skeleton_archer',
      hp: 55,
      damage: 26,
      speed: 0.9,
      spawnIntervalSeconds: 2.4,
      isRanged: true,
      range: 4.5,
      attackKind: EnemyAttackKind.arrow,
      coinReward: 6,
      aggroRange: 4.5,
    ),
    // Goblin: small, fast and cackling. Low HP and a weak stab, but they show
    // up in packs, sprint at your line and swarm whoever they reach first.
    EnemyType.goblin: EnemyDef(
      type: EnemyType.goblin,
      displayName: 'Goblin',
      spriteName: 'goblin',
      hp: 70,
      damage: 16,
      speed: 1.7,
      spawnIntervalSeconds: 1.2,
      coinReward: 3,
      meleeReach: 0.9,
      attackInterval: 0.7,
      aggroRange: 4.0,
    ),
    // Apex predator: fast, heavily armored and vicious. Fangs and claws tear
    // through the army — every strike comes quickly, and the claw sweep rakes
    // the whole squad standing next to its victim. Expect to lose units
    // fighting it; focus it down with towers before it reaches the line.
    EnemyType.lizard: EnemyDef(
      type: EnemyType.lizard,
      displayName: 'Lizard',
      spriteName: 'lizard',
      hp: 1500,
      damage: 85,
      speed: 1.5,
      spawnIntervalSeconds: 4.0,
      coinReward: 40,
      meleeReach: 1.25,
      attackInterval: 0.55,
      aggroRange: 5.5,
      cleaveRadius: 1.3,
      cleaveFraction: 0.6,
    ),
    // Slow, heavy brute — the opposite tradeoff from the Lizard: takes a
    // while to arrive but hits hard and soaks a lot of damage on the way.
    EnemyType.monster: EnemyDef(
      type: EnemyType.monster,
      displayName: 'Monster',
      spriteName: 'monster',
      // Buffed: at 230 hp / 0.65 speed our ranged heroes (range 6-7) killed it
      // long before it got within claw reach (1.35), so it never hurt anyone.
      hp: 900,
      damage: 60,
      speed: 0.85,
      spawnIntervalSeconds: 3.6,
      coinReward: 12,
      // Long arms + big jaws: hits from further away, but swings slowly.
      meleeReach: 1.35,
      attackInterval: 1.5,
      aggroRange: 4.0,
    ),

    // ================= THUNDERSTORM CHAPTER ENEMIES =================
    // Armored bruiser in storm-forged plate: tanky, hits hard, sweeps squads.
    EnemyType.stormKnight: EnemyDef(
      type: EnemyType.stormKnight,
      displayName: 'Storm Knight',
      spriteName: 'storm_knight',
      hp: 900,
      damage: 70,
      speed: 0.9,
      spawnIntervalSeconds: 3.0,
      // Melee swordsman: marches on the castle and slashes it directly with
      // his sword; the sweep also cuts down every soldier around the target
      // (or standing near the wall).
      isRanged: false,
      attackKind: EnemyAttackKind.swordSlash,
      meleeReach: 1.3,
      coinReward: 30,
      attackInterval: 1.1,
      aggroRange: 3.0,
      cleaveRadius: 1.6, // sword sweep radius
      cleaveFraction: 0.6, // sweep victims take 60%
      fallbackSprite: 'monster',
      fallbackTint: 0xFF5C6BC0,
    ),
    // Burning hellhound: paper-thin but blindingly fast; arrives in packs.
    EnemyType.emberHound: EnemyDef(
      type: EnemyType.emberHound,
      displayName: 'Ember Hound',
      spriteName: 'ember_hound',
      hp: 260,
      damage: 45,
      speed: 2.2,
      spawnIntervalSeconds: 1.5,
      // Barks and a jet of fire shoots out of its mouth.
      isRanged: true,
      range: 2.0,
      attackKind: EnemyAttackKind.fireBreath,
      coinReward: 10,
      attackInterval: 0.9,
      aggroRange: 7.0,
      cleaveRadius: 0.9, // flame splash
      cleaveFraction: 0.5,
      fallbackSprite: 'lizard',
      fallbackTint: 0xFFFF6D00,
    ),
    // Lightning-hurling sorcerer: squishy, but snipes from far away.
    EnemyType.stormCaller: EnemyDef(
      type: EnemyType.stormCaller,
      displayName: 'Storm Caller',
      spriteName: 'storm_caller',
      hp: 420,
      damage: 95,
      speed: 0.8,
      spawnIntervalSeconds: 3.5,
      // Conjures a storm cell right on top of your army.
      isRanged: true,
      range: 9.0,
      attackKind: EnemyAttackKind.stormSummon,
      coinReward: 25,
      attackInterval: 5.0,
      aggroRange: 9.0,
      fallbackSprite: 'skeleton_archer',
      fallbackTint: 0xFF7C4DFF,
    ),
    // Wave-5/10/15... juggernaut: a walking thunderhead with enormous HP.
    EnemyType.thunderTitan: EnemyDef(
      type: EnemyType.thunderTitan,
      displayName: 'Thunder Titan',
      spriteName: 'thunder_titan',
      hp: 6000,
      damage: 180,
      speed: 0.55,
      spawnIntervalSeconds: 8.0,
      // Hurls flaming boulders (small at first, huge on impact) at your
      // army AND your castle.
      isRanged: true,
      range: 10.0,
      attackKind: EnemyAttackKind.fireStones,
      coinReward: 120,
      attackInterval: 2.2,
      aggroRange: 10.0,
      cleaveRadius: 1.4, // boulder blast radius
      cleaveFraction: 0.6,
      fallbackSprite: 'monster',
      fallbackTint: 0xFFFFD600,
    ),

    // ================= BLACK DRAGON (the "bad dragon") =================
    // Big black dragon that flies in with the boss waves (and keeps coming in
    // Endless). It stops at a distance and burns your soldiers (and, once no
    // soldier is left in sight, your castle) with a jet of fire; the flames
    // splash onto the units standing next to the target. Its range is a bit
    // shorter than an Archer's (7.0) so your archers can shoot back first.
    // Art: assets/kenney/enemies/black_dragon.png (see the ludo.ai prompt);
    // until that file exists the good dragon's art is shown, washed in black.
    EnemyType.blackDragon: EnemyDef(
      type: EnemyType.blackDragon,
      displayName: 'Black Dragon',
      spriteName: 'black_dragon',
      hp: 2600,
      damage: 75,
      speed: 0.7,
      spawnIntervalSeconds: 9.0,
      isFlying: true,
      isRanged: true,
      range: 6.5,
      attackKind: EnemyAttackKind.fireBreath,
      coinReward: 90,
      attackInterval: 1.8,
      aggroRange: 8.0,
      cleaveRadius: 1.5,
      cleaveFraction: 0.6,
      fallbackSprite: 'good_dragon',
      fallbackTint: 0xFF101010,
    ),
  };

  static EnemyDef defFor(EnemyType type) => defs[type]!;
}
