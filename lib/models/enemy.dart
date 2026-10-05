// Runtime instance of a single enemy-owned army unit on the battlefield.
// Mirrors Unit but tracks enemy-only fields (isBoss) and status effects
// applied by towers/spells (slow, burn) since those only ever target enemies.

enum EnemyType {
  skeleton,
  skeletonArcher,
  goblin, // fast, cheap swarm raider
  lizard,
  monster,
  // --- Thunderstorm chapter exclusives ---
  stormKnight,
  emberHound,
  stormCaller,
  thunderTitan,
  // --- Bad dragon (black, flying fire-breather; boss waves + endless) ---
  blackDragon,
}

/// How an enemy actually attacks. [melee] and [arrow] are the original two;
/// the rest are the Thunderstorm chapter's special attacks (see BattleEngine).
enum EnemyAttackKind {
  melee,
  arrow,
  lightning, // (unused now) instant chain-lightning
  swordSlash, // Storm Knight: sword slash on castle + sweep on soldiers
  fireBreath, // Ember Hound: barks and breathes a jet of flame
  stormSummon, // Storm Caller: conjures a storm cell over your army
  fireStones, // Thunder Titan: hurls burning boulders that grow in flight
}

class Enemy {
  final String id;
  final EnemyType type;
  final String spriteName;

  final int maxHp;
  final int damage;
  final double baseSpeed; // unaffected-by-slow speed, tiles/units per second
  final bool isFlying;
  final bool isBoss;
  final bool isRanged; // true for bow-armed enemies like the skeleton archer
  final double range; // 0 for melee; engagement distance for ranged enemies
  final EnemyAttackKind attackKind;

  // Melee behaviour (see BattleEngine._updateEnemies): an enemy notices any
  // of your units within [aggroRange], walks up to them, and once within
  // [meleeReach] strikes on its own every [attackInterval] seconds.
  final double meleeReach;
  final double attackInterval;
  final double aggroRange;

  // Claw sweep: a melee strike also rakes every other unit within this
  // radius of the target for [cleaveFraction] of its damage (0 = no sweep).
  final double cleaveRadius;
  final double cleaveFraction;

  // Render hints written by the engine, read by EnemyComponent.
  int strikeCount = 0; // +1 every time this enemy attacks (bite/claw/arrow)
  double aimX = 0; // world position of whatever the last strike was aimed at
  double aimY = 0;
  bool attackingCastle = false;

  // Mind control (Elf Prince): a charmed enemy fights FOR the player against
  // the rest of the enemy army until [charmTimeLeft] runs out.
  bool charmed = false;
  double charmTimeLeft = 0;
  bool facingLeft = true; // enemies start on the right and march left

  double x;
  double y;
  int hp;
  bool alive;
  String? targetUnitId; // id of Unit currently engaged/targeted
  double attackCooldown;

  // Status effects applied by towers/spells.
  double slowFactor; // 0 = no slow, 0.5 = 50% slower, etc. Decays via duration.
  double slowDurationRemaining;
  int burnDamagePerTick;
  double burnDurationRemaining;

  Enemy({
    required this.id,
    required this.type,
    required this.spriteName,
    required this.maxHp,
    required this.damage,
    required this.baseSpeed,
    required this.x,
    required this.y,
    this.isFlying = false,
    this.isBoss = false,
    this.isRanged = false,
    this.range = 0,
    this.attackKind = EnemyAttackKind.melee,
    this.meleeReach = 1.0,
    this.attackInterval = 1.0,
    this.aggroRange = 3.0,
    this.cleaveRadius = 0,
    this.cleaveFraction = 0.6,
    int? hp,
    this.alive = true,
    this.targetUnitId,
    this.attackCooldown = 0,
    this.slowFactor = 0,
    this.slowDurationRemaining = 0,
    this.burnDamagePerTick = 0,
    this.burnDurationRemaining = 0,
  }) : hp = hp ?? maxHp;

  double get effectiveSpeed => baseSpeed * (1 - slowFactor).clamp(0.0, 1.0);

  bool get isDead => hp <= 0;

  void takeDamage(int amount) {
    hp -= amount;
    if (hp <= 0) {
      hp = 0;
      alive = false;
    }
  }

  void applySlow(double factor, double durationSeconds) {
    // Strongest slow wins if two overlap.
    if (factor > slowFactor) {
      slowFactor = factor;
      slowDurationRemaining = durationSeconds;
    }
  }

  void applyBurn(int damagePerTick, double durationSeconds) {
    burnDamagePerTick = damagePerTick;
    burnDurationRemaining = durationSeconds;
  }
}
