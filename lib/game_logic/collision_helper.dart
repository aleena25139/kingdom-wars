// Distance-based "collision" checks used instead of Flame's collision
// system, per the architecture rule (ALL logic is pure Dart math).
import 'dart:math' as math;

class CollisionHelper {
  CollisionHelper._();

  static double distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  static bool withinRange(
    double x1,
    double y1,
    double x2,
    double y2,
    double range,
  ) {
    return distance(x1, y1, x2, y2) <= range;
  }

  /// Melee "contact" check — smaller radius than a tower's range, used to
  /// decide when two marching units are close enough to start fighting.
  /// 1.0 world unit == 48px == one full sprite width, so at this distance
  /// the two sprites' edges just meet instead of overlapping — previously
  /// this was 0.6 (29px), which made units stop while already ~20px deep
  /// inside each other, reading as a glitch rather than a stand-and-fight.
  static const double meleeEngageDistance = 1.0;

  static bool inMeleeRange(double x1, double y1, double x2, double y2) {
    return distance(x1, y1, x2, y2) <= meleeEngageDistance;
  }
}
