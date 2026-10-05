// Runtime instance of a tower placed on the grid. Static per-type/per-level
// stats (cost, damage, range, special effect) live in tower_data.dart —
// this class just tracks which type/level/slot a placed tower is, plus its
// live attack-cooldown timer. TowerComponent (Flame) reads this to render
// and to draw range indicators; it never mutates cooldown/targeting itself.

enum TowerType { cannon, archer, mage, flamethrower, sniper, tesla }

class Tower {
  final String id;
  final TowerType type;
  final int gridCol;
  final int gridRow;
  final double x; // pixel/world position derived from grid slot
  final double y;

  int level; // 1, 2, or 3
  double attackCooldown;
  String? currentTargetEnemyId;

  Tower({
    required this.id,
    required this.type,
    required this.gridCol,
    required this.gridRow,
    required this.x,
    required this.y,
    this.level = 1,
    this.attackCooldown = 0,
    this.currentTargetEnemyId,
  });

  bool get isMaxLevel => level >= 3;

  void upgrade() {
    if (!isMaxLevel) level += 1;
  }
}
