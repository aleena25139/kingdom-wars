// Renders a single projectile -- a tower's shot, a player archer's arrow, or
// an enemy skeleton archer's arrow. Purely cosmetic -- position is driven
// entirely by Projectile.x/y, which battle_engine.dart advances toward its
// target each tick. Also rotates the sprite to face wherever it's actually
// travelling this frame (computed here from consecutive positions, no model
// changes needed) so arrows visibly point along their flight path instead of
// sitting at a fixed angle.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/projectile.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';

class ProjectileComponent extends PositionComponent {
  final Projectile projectile;
  final KingdomWarsGame game;

  // The arrow art (shared by player archers and skeleton archers) is a long,
  // thin side-view arrow -- rendering it at the same square size as a
  // cannonball/fireball would squash it, so it gets its own elongated size
  // matching the source image's real aspect ratio.
  static const double _arrowLength = 26.0;

  Vector2? _lastWorldPos;

  // Fire stones (Thunder Titan) and fireballs (Phoenix) are drawn in code
  // when no PNG exists, so they're never invisible.
  bool _procedural = false;
  bool get _isStone => projectile.spriteName == 'fire_stone';
  bool get _isMagicBall => projectile.spriteName == 'projectile_magic_ball';

  ProjectileComponent({required this.projectile, required this.game})
      : super(size: Vector2.all(16), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = game.worldToScreen(projectile.x, projectile.y);
    _lastWorldPos = position.clone();

    final assetPath = SpriteRegistry.pathFor(projectile.spriteName);
    final fileName = assetPath.replaceFirst('assets/', '');
    if (game.images.containsKey(fileName)) {
      final image = game.images.fromCache(fileName);
      if (projectile.spriteName == 'projectile_arrow' && image.height > 0) {
        final aspect = image.width / image.height;
        size = Vector2(_arrowLength, _arrowLength / aspect);
      }
      add(SpriteComponent(sprite: Sprite(image), size: size));
    } else if (_isStone || _isMagicBall || projectile.spriteName == 'projectile_fireball') {
      _procedural = true;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_procedural) return;
    final c = Offset(size.x / 2, size.y / 2);
    final p = projectile.progress;
    if (_isMagicBall) {
      // Magician's magic ball: a glowing green-gold orb with a shimmering
      // trail and a few orbiting sparkles.
      const r = 6.5;
      final pulse = 0.85 + 0.15 * math.sin(p * 70);
      canvas.drawCircle(
        c.translate(-r * 1.3, 0),
        r * 1.5,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        c,
        r * 2.0 * pulse,
        Paint()
          ..color = const Color(0xFFB9F6CA).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF00E676));
      canvas.drawCircle(c, r * 0.65, Paint()..color = const Color(0xFFFFF59D));
      canvas.drawCircle(c, r * 0.3, Paint()..color = Colors.white);
      final spark = Paint()..color = const Color(0xFFFFF176);
      for (var i = 0; i < 3; i++) {
        final a = p * 40 + i * 2.1;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 1.6, 1.3, spark);
      }
      return;
    }
    // Stone: tiny when thrown, huge on impact. Fireball: constant size.
    final r = _isStone ? 5.0 + 20.0 * Curves.easeIn.transform(p) : 7.0;
    final flick = 0.85 + 0.15 * math.sin(p * 90);
    // Flame tail streaming behind (local -x is behind the direction of travel).
    final tail = Path()
      ..moveTo(c.dx, c.dy - r * 0.9)
      ..quadraticBezierTo(c.dx - r * 2.2, c.dy - r * 0.6, c.dx - r * 3.4 * flick, c.dy)
      ..quadraticBezierTo(c.dx - r * 2.2, c.dy + r * 0.6, c.dx, c.dy + r * 0.9)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(tail, Paint()..color = const Color(0xFFFFA000).withValues(alpha: 0.7));
    // Glow.
    canvas.drawCircle(
      c,
      r * 1.7,
      Paint()
        ..color = const Color(0xFFFF5722).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    if (_isStone) {
      // Charred rock body (lumpy) with glowing cracks.
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3B2A26));
      canvas.drawCircle(c.translate(-r * 0.25, -r * 0.25), r * 0.7, Paint()..color = const Color(0xFF5D4037));
      final crack = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max<double>(1.2, r * 0.13)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c.translate(-r * 0.6, -r * 0.1), c.translate(-r * 0.05, r * 0.25), crack);
      canvas.drawLine(c.translate(-r * 0.05, r * 0.25), c.translate(r * 0.5, -r * 0.2), crack);
      canvas.drawLine(c.translate(-r * 0.05, r * 0.25), c.translate(r * 0.1, r * 0.7), crack);
    } else {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFF7043));
      canvas.drawCircle(c, r * 0.6, Paint()..color = const Color(0xFFFFCA28));
      canvas.drawCircle(c, r * 0.3, Paint()..color = const Color(0xFFFFF9C4));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Dead arrow (hit / target gone): remove at once, never leave it hanging
    // in the air -- this is what made arrows "stick" at 2x / 3x speed.
    if (!projectile.alive) {
      removeFromParent();
      return;
    }
    final newPos = game.worldToScreen(projectile.x, projectile.y);

    // The arrow art points rightward (+x) at angle 0 in its source image, so
    // atan2(dy, dx) of the actual on-screen movement this frame lines it up
    // with the real flight direction -- whether that's toward an enemy off
    // to the right or an enemy archer shooting back toward the castle on
    // the left.
    if (_lastWorldPos != null) {
      final delta = newPos - _lastWorldPos!;
      if (delta.length2 > 0.0001) {
        angle = math.atan2(delta.y, delta.x);
      }
    }
    _lastWorldPos = newPos.clone();
    // Fire stones are LOBBED: they rise in an arc and drop onto the target.
    final arc = _isStone ? math.sin(projectile.progress * math.pi) * 54.0 : 0.0;
    position = newPos - Vector2(0, arc);
  }
}
