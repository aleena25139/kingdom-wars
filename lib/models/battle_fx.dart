// Purely-visual and hazard entities that aren't units/enemies/projectiles:
//   * StormZone  - a storm cell conjured by a Storm Caller over your army.
//                  It gathers for [warmup] seconds (a warning ring), then
//                  rains lightning for [duration] seconds, hurting every
//                  soldier (and the castle, if close) inside [radius].
//   * BattleEffect - short-lived render-only effects (lightning bolts, fire
//                  jets, explosions, heal rings, barks). BattleEngine
//                  creates them, ages them, and drops them when expired;
//                  StormFxComponent draws them. They never affect gameplay.

class StormZone {
  final double x;
  final double y;
  final double radius; // world units
  final int tickDamage; // damage to every soldier inside, every 0.5s
  final double warmup; // seconds of warning before it starts hurting
  final double duration; // seconds it keeps raining lightning
  double age = 0;
  double tickTimer = 0.5;
  final int seed;

  StormZone({
    required this.x,
    required this.y,
    required this.radius,
    required this.tickDamage,
    this.warmup = 0.9,
    this.duration = 3.6,
    this.seed = 0,
  });

  bool get isActive => age >= warmup;
  bool get expired => age >= warmup + duration;
}

enum BattleEffectKind {
  bolt, // jagged lightning from (x,y) to (x2,y2)
  fireJet, // flame jet from (x,y) to (x2,y2)
  explosion, // fiery blast at (x,y) with [radius]
  stormStrike, // a lightning strike hitting the ground at (x,y)
  heal, // green-gold healing ring at (x,y)
  bark, // "GRAWR!" bubble above (x,y)
  blueBolt, // Mage: blue lightning from (x,y) to (x2,y2)
  skyFire, // Elf Prince: fire falling from the sky onto (x,y)
  stormCast, // Storm Caller: hand raised, storm energy streams from (x,y) to (x2,y2)
  fireBreath, // Dragon / Phoenix: flame breathed from the mouth (x,y) onto (x2,y2)
  magicBurst, // Magician: magic ball bursting on an enemy at (x,y)
  swordSlash, // Storm Knight: big sword slash arc at (x2,y2), swung from (x,y)
}

class BattleEffect {
  final BattleEffectKind kind;
  final double x;
  final double y;
  final double x2;
  final double y2;
  final double radius;
  final double life;
  final int seed;
  // fireBreath only: true when the breather hovers in the air (Phoenix), so the
  // flame is drawn from the mouth of the HOVERING sprite, not the ground point.
  final bool airborne;
  // fireBreath only: which way the breather faces and how big its sprite is,
  // so the flame starts at the correct side of the mouth.
  final bool facingLeft;
  final double creatureSize;
  // fireBreath only: px the breather floats above its ground point (black dragon).
  final double hover;
  double age = 0;

  BattleEffect({
    required this.kind,
    required this.x,
    required this.y,
    this.x2 = 0,
    this.y2 = 0,
    this.radius = 1.0,
    this.life = 0.4,
    this.seed = 0,
    this.airborne = false,
    this.facingLeft = false,
    this.creatureSize = 30.0,
    this.hover = 0.0,
  });

  double get progress => (age / life).clamp(0.0, 1.0);
  bool get expired => age >= life;
}
