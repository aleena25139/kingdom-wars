// Runtime model for a castle (either the player's or the enemy's). Holds HP
// and, for the player's castle, the current upgrade level and spawn timer
// used by ArmyManager to know when to spawn the next auto-unit.
import '../constants/game_balance.dart';

enum CastleOwner { player, enemy }

class Castle {
  final CastleOwner owner;
  final double x;
  final double y;

  int level; // only meaningful for owner == player (1..5)
  int hp;
  int maxHp;
  double spawnTimer; // counts down; on reaching 0, ArmyManager/WaveManager spawns a unit

  Castle({
    required this.owner,
    required this.x,
    required this.y,
    this.level = 1,
    required this.maxHp,
    int? hp,
    this.spawnTimer = 0,
  }) : hp = hp ?? maxHp;

  factory Castle.playerAtLevel(int level, {required double x, required double y}) {
    final stat = GameBalance.castleStatFor(level);
    return Castle(
      owner: CastleOwner.player,
      x: x,
      y: y,
      level: level,
      maxHp: stat.hp,
      spawnTimer: stat.spawnIntervalSeconds,
    );
  }

  bool get isDestroyed => hp <= 0;

  void takeDamage(int amount) {
    hp -= amount;
    if (hp < 0) hp = 0;
  }

  double get hpPercent => maxHp == 0 ? 0 : hp / maxHp;

  /// Applies the next castle level's stats (called after an upgrade purchase).
  void upgradeToLevel(int newLevel) {
    final stat = GameBalance.castleStatFor(newLevel);
    final hpGain = stat.hp - maxHp;
    level = newLevel;
    maxHp = stat.hp;
    hp += hpGain > 0 ? hpGain : 0; // carry over current damage proportionally-free (simple add)
    if (hp > maxHp) hp = maxHp;
  }
}
