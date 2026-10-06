// Shared ground-shadow renderer used by every battlefield sprite (units,
// enemies, towers, the castle) so MapComponent's day/night lighting actually
// looks like it's lighting something. Opacity and horizontal skew both
// track KingdomWarsGame's current sun/moon position, so shadows swing
// underfoot over the course of a cycle and fade out right at sunrise/sunset
// the way real ground shadows do.
import 'dart:ui';

import 'package:flame/components.dart';

import '../kingdom_wars_game.dart';

void drawGroundShadow(Canvas canvas, KingdomWarsGame game, Vector2 componentSize) {
  final strength = game.shadowStrength;
  if (strength <= 0.02) return;

  final skew = game.shadowSkew; // -1..1, follows the sun/moon across the sky
  final width = componentSize.x * 0.72;
  final height = componentSize.y * 0.22;
  final baseY = componentSize.y * 0.94;
  final centerX = componentSize.x / 2 + skew * componentSize.x * 0.3;

  final rect = Rect.fromCenter(center: Offset(centerX, baseY), width: width, height: height);
  canvas.drawOval(
    rect,
    Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.3 * strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
}
