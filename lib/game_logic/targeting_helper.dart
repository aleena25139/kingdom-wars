// Pure functions for picking a target: units target the nearest enemy,
// enemies target the nearest unit (or the player castle if none in range),
// and towers target the nearest enemy within their range. No Flame/physics
// involved — just list scans + CollisionHelper distance math.
import '../models/unit.dart';
import '../models/enemy.dart';
import '../models/tower.dart';
import 'collision_helper.dart';

class TargetingHelper {
  TargetingHelper._();

  static Enemy? nearestEnemyTo(
    double x,
    double y,
    List<Enemy> enemies, {
    double? maxRange,
    bool flyingOnly = false,
  }) {
    Enemy? best;
    double bestDist = double.infinity;
    for (final e in enemies) {
      if (!e.alive || e.charmed) continue; // charmed = on our side now
      if (flyingOnly && !e.isFlying) continue;
      final d = CollisionHelper.distance(x, y, e.x, e.y);
      if (maxRange != null && d > maxRange) continue;
      if (d < bestDist) {
        bestDist = d;
        best = e;
      }
    }
    return best;
  }

  static Unit? nearestUnitTo(
    double x,
    double y,
    List<Unit> units, {
    double? maxRange,
    bool skipAirStrikers = false,
  }) {
    Unit? best;
    double bestDist = double.infinity;
    for (final u in units) {
      if (!u.alive) continue;
      // Melee enemies can't reach a bird hovering in the sky.
      if (skipAirStrikers && u.isAirStriker) continue;
      final d = CollisionHelper.distance(x, y, u.x, u.y);
      if (maxRange != null && d > maxRange) continue;
      if (d < bestDist) {
        bestDist = d;
        best = u;
      }
    }
    return best;
  }

  static Enemy? bestTowerTarget(Tower tower, List<Enemy> enemies, double range) {
    // Towers prioritize the enemy furthest along the lane (closest to the
    // player castle) among those in range, so damage focuses the biggest
    // threat first rather than whichever spawned nearest the tower.
    Enemy? best;
    double bestProgress = -double.infinity;
    for (final e in enemies) {
      if (!e.alive || e.charmed) continue;
      final d = CollisionHelper.distance(tower.x, tower.y, e.x, e.y);
      if (d > range) continue;
      final progress = -e.x; // more negative x (further toward player) = higher priority
      if (progress > bestProgress) {
        bestProgress = progress;
        best = e;
      }
    }
    return best;
  }

  static List<Unit> unitsWithinRadius(
    double x,
    double y,
    double radius,
    List<Unit> units,
  ) {
    return units
        .where((u) => u.alive && CollisionHelper.withinRange(x, y, u.x, u.y, radius))
        .toList();
  }

  static List<Enemy> enemiesWithinRadius(
    double x,
    double y,
    double radius,
    List<Enemy> enemies,
  ) {
    return enemies
        .where((e) => e.alive && !e.charmed && CollisionHelper.withinRange(x, y, e.x, e.y, radius))
        .toList();
  }
}
