// Runtime instance of any fired projectile — a tower's shot, a player
// archer's arrow, or an enemy skeleton archer's arrow — traveling toward
// (or homing on) whatever it was aimed at. GameEngine/BattleEngine advances
// position each tick using plain math (no Flame physics); ProjectileComponent
// only renders x/y (and, for arrows, the direction of travel).

enum ProjectileEffect { none, splash, slow, burn, chain }

/// What a projectile is flying toward. Towers only ever fire at enemies;
/// player archers also fire at enemies; enemy archers fire back at whichever
/// unit engaged them, or -- once they've slipped past every unit -- at the
/// player's castle directly.
enum ProjectileTargetKind { enemy, unit, castle }

class Projectile {
  final String id;
  final String spriteName;

  /// Set only for tower-fired projectiles; null for unit/enemy arrows.
  final String? sourceTowerId;

  final ProjectileTargetKind targetKind;
  final String? targetEnemyId; // set when targetKind == enemy
  final String? targetUnitId; // set when targetKind == unit
  // targetKind == castle has no id -- there's only ever one player castle.

  final int damage;
  final double speed; // units per second
  final ProjectileEffect effect;
  final double effectMagnitude; // splash radius, slow factor, burn dmg/tick, etc.
  final double effectDuration; // for slow/burn
  final int chainCount; // for tesla-style chaining

  // Where it was launched from (lets renderers compute flight progress, e.g.
  // the Thunder Titan's fire stones grow as they travel).
  final double originX;
  final double originY;
  // Fraction of [damage] dealt to every soldier within [effectMagnitude] of the
  // impact point when [effect] == splash and the target is on the player's side.
  final double splashFraction;

  // Written by BattleEngine each tick: total flight distance and how far along
  // (0..1) the projectile is. Renderers use it for arcs/growth (fire stones).
  double travelTotal = 0;
  double progress = 0;

  double x;
  double y;
  bool alive;

  Projectile({
    required this.id,
    required this.spriteName,
    required this.targetKind,
    required this.damage,
    required this.speed,
    required this.x,
    required this.y,
    this.sourceTowerId,
    this.targetEnemyId,
    this.targetUnitId,
    this.effect = ProjectileEffect.none,
    this.effectMagnitude = 0,
    this.effectDuration = 0,
    this.chainCount = 0,
    this.splashFraction = 0.5,
    this.alive = true,
  })  : originX = x,
        originY = y;
}
