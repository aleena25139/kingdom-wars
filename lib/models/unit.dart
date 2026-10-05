// Runtime instance of a single player-owned army unit on the battlefield.
// Static per-type stats (baseHp, baseDamage, etc.) live in unit_data.dart —
// this class holds the mutable, per-instance state that GameEngine mutates
// every tick. No Flame imports here; UnitComponent (in game/components)
// reads this model to render.

enum UnitType {
  archer,
  knight,
  mage,
  dragon,
  pandaWarrior,
  // --- Elite units (built to survive the Thunderstorm chapter) ---
  elfPrince,
  magician,
  phoenix,
}

class Unit {
  final String id;
  final UnitType type;
  final String spriteName;

  // Static-derived stats (copied in at spawn time so upgrades mid-battle
  // don't retroactively change units already on the field).
  final int maxHp;
  final int damage;
  final double speed; // tiles/units per second
  final bool isRanged;
  final double range; // 0 for melee
  final bool isFlying;
  final bool isAoe;
  final bool healsNearby;
  final bool usesLightning;
  // Panda Warrior only: fights with kung-fu himself — flying kick, spin
  // kick and a palm-strike flurry, cycling per hit (see [comboCount] and
  // UnitComponent._kungFuMove). Every 3rd hit is a spin kick that also
  // sweeps nearby enemies (see BattleEngine).
  final bool usesKungFu;
  // Elf Prince only: periodically MIND-CONTROLS nearby Goblins and Orcs
  // (Monsters) so they switch sides and fight for you (see
  // BattleEngine._tickMindControl).
  final bool usesMindControl;
  double charmTimer = 4.0; // seconds until the next mind-control cast
  int level = 1; // upgrade level this soldier was spawned at

  // Air-strike units (Phoenix) fly out to this lane x and hover there.
  // 0 = holds its formation slot.
  final double advanceToX;
  final double advanceSpeed;
  bool get isAirStriker => advanceToX > 0;

  // Mutable battlefield state.
  double x;
  double y;
  int hp;
  bool alive;
  String? targetEnemyId; // id of Enemy currently engaged/targeted
  double attackCooldown; // seconds remaining until next attack
  int comboCount = 0; // +1 per landed kung-fu hit; picks which move to play
  double healTimer = 1.0; // Magician: seconds until the next healing pulse
  int slot = -1; // formation slot this soldier stands in (see ArmyManager)
  String formationKey = ''; // stable id of this soldier's place in the army, e.g. "archer#2"
  // Set when the player rearranges the formation mid-battle: the soldier
  // glides to this spot (null = already standing where it should).
  double? homeX;
  double? homeY;

  // Dragon / Phoenix: which way the creature is looking. Sprites are drawn
  // facing RIGHT; when the target is behind (to the left) the engine flips
  // this, waits [turnWait] seconds (the turn animation) and only THEN fires.
  bool facingLeft = false;
  double turnWait = 0;

  Unit({
    required this.id,
    required this.type,
    required this.spriteName,
    required this.maxHp,
    required this.damage,
    required this.speed,
    required this.x,
    required this.y,
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
    int? hp,
    this.alive = true,
    this.targetEnemyId,
    this.attackCooldown = 0,
  }) : hp = hp ?? maxHp;

  bool get isDead => hp <= 0;

  void takeDamage(int amount) {
    hp -= amount;
    if (hp <= 0) {
      hp = 0;
      alive = false;
    }
  }
}
