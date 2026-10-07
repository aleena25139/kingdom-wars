// Draws everything the Thunderstorm chapter adds on top of the battlefield,
// all in one component (no per-entity components to sync):
//   * StormZone  - a dark storm cell over your army: a pulsing warning ring
//                  while it gathers, then swirling cloud, rain and flashes.
//   * BattleEffect - lightning bolts (Storm Knight / Caller casting), fire
//                  jets (Ember Hound), stone explosions (Thunder Titan),
//                  ground lightning strikes, heal rings and "GRAWR!" barks.
// It only READS BattleEngine's lists; nothing here affects gameplay.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/unit_data.dart';
import '../../models/battle_fx.dart';
import '../../models/unit.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';

class StormFxComponent extends PositionComponent {
  final KingdomWarsGame game;

  StormFxComponent({required this.game}) : super(priority: 50);

  @override
  void render(Canvas canvas) {
    final battle = game.provider.gameEngine.activeBattle;
    if (battle == null) return;
    final ppu = game.pixelsPerUnit;
    final t = game.dayNightClock;

    Offset toScreen(double x, double y) {
      final v = game.worldToScreen(x, y);
      return Offset(v.x, v.y);
    }

    for (final z in battle.stormZones) {
      _renderZone(canvas, z, toScreen(z.x, z.y), ppu, t);
    }
    for (final e in battle.effects) {
      switch (e.kind) {
        case BattleEffectKind.bolt:
          _renderBolt(canvas, toScreen(e.x, e.y), toScreen(e.x2, e.y2), e);
          break;
        case BattleEffectKind.fireJet:
          _renderFireJet(canvas, toScreen(e.x, e.y), toScreen(e.x2, e.y2), e);
          break;
        case BattleEffectKind.explosion:
          _renderExplosion(canvas, toScreen(e.x, e.y), e.radius * ppu, e);
          break;
        case BattleEffectKind.stormStrike:
          _renderGroundStrike(canvas, toScreen(e.x, e.y), e);
          break;
        case BattleEffectKind.heal:
          _renderHeal(canvas, toScreen(e.x, e.y), e.radius * ppu, e);
          break;
        case BattleEffectKind.bark:
          _renderBark(canvas, toScreen(e.x, e.y), e);
          break;
        case BattleEffectKind.blueBolt:
          _renderBolt(canvas, toScreen(e.x, e.y), toScreen(e.x2, e.y2), e, blue: true);
          break;
        case BattleEffectKind.fireBreath:
          _renderFireBreath(canvas, _breathMouth(toScreen(e.x, e.y), e, t), toScreen(e.x2, e.y2).translate(0, -14), e);
          break;
        case BattleEffectKind.magicBurst:
          _renderMagicBurst(canvas, toScreen(e.x, e.y), e.radius * ppu, e);
          break;
        case BattleEffectKind.skyFire:
          _renderSkyFire(canvas, toScreen(e.x, e.y), e);
          break;
        case BattleEffectKind.stormCast:
          _renderStormCast(canvas, toScreen(e.x, e.y), toScreen(e.x2, e.y2), e);
          break;
        case BattleEffectKind.swordSlash:
          _renderSwordSlash(canvas, toScreen(e.x, e.y), toScreen(e.x2, e.y2), e);
          break;
      }
    }
  }

  // ---------------------------------------------------------------- zones
  void _renderZone(Canvas canvas, StormZone z, Offset c, double ppu, double t) {
    final r = z.radius * ppu;
    if (!z.isActive) {
      // Warning: a growing, pulsing red-violet ring on the ground.
      final k = (z.age / z.warmup).clamp(0.0, 1.0);
      final pulse = 0.5 + 0.5 * math.sin(t * 16);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2 * k, height: r * 1.2 * k),
        Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.18 + 0.12 * pulse),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 1.2),
        Paint()
          ..color = const Color(0xFFFF5252).withValues(alpha: 0.5 + 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _cloud(canvas, c.translate(0, -r * 0.9), r, 0.4 + 0.5 * k, t, z.seed);
      return;
    }
    final life = ((z.age - z.warmup) / z.duration).clamp(0.0, 1.0);
    final fade = life > 0.85 ? (1 - life) / 0.15 : 1.0;
    // Charged ground.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2, height: r * 1.2),
      Paint()..color = const Color(0xFF4A2A9A).withValues(alpha: 0.28 * fade),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2, height: r * 1.2),
      Paint()
        ..color = const Color(0xFFB39DFF).withValues(alpha: 0.7 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _cloud(canvas, c.translate(0, -r * 0.9), r, fade, t, z.seed);
    // Rain curtain under the cloud.
    final rain = Paint()
      ..color = const Color(0xFFCFE0FF).withValues(alpha: 0.55 * fade)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final fx = ((i * 0.618 + z.seed * 0.013) % 1.0) - 0.5;
      final x = c.dx + fx * r * 1.7;
      final y0 = c.dy - r * 0.8 + ((t * 260 + i * 31) % (r * 1.7));
      canvas.drawLine(Offset(x, y0), Offset(x - 3, y0 + 11), rain);
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, double alpha, double t, int seed) {
    final paint = Paint()..color = const Color(0xFF14121F).withValues(alpha: 0.92 * alpha.clamp(0.0, 1.0));
    final glow = Paint()
      ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.25 * alpha.clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.3, height: r * 0.9), glow);
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * 2 * math.pi + t * 0.8;
      final o = Offset(math.cos(a) * r * 0.75, math.sin(a) * r * 0.16);
      canvas.drawCircle(c + o, r * (0.38 + 0.06 * ((i + seed) % 3)), paint);
    }
    canvas.drawCircle(c, r * 0.5, paint);
  }

  // ---------------------------------------------------------------- bolts
  Path _zigzag(Offset a, Offset b, int seed, {double jitter = 14, int segments = 8}) {
    final rng = math.Random(seed);
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final path = Path()..moveTo(a.dx, a.dy);
    if (len < 1) return path;
    final nx = -dy / len;
    final ny = dx / len;
    for (var i = 1; i < segments; i++) {
      final k = i / segments;
      final j = (rng.nextDouble() - 0.5) * jitter;
      path.lineTo(a.dx + dx * k + nx * j, a.dy + dy * k + ny * j);
    }
    path.lineTo(b.dx, b.dy);
    return path;
  }

  void _renderBolt(Canvas canvas, Offset a, Offset b, BattleEffect e, {bool blue = false}) {
    final fade = (1 - e.progress).clamp(0.0, 1.0);
    // Flicker: re-roll the shape a few times over its life.
    final seed = e.seed + (e.progress * 4).floor() * 977;
    final path = _zigzag(a.translate(0, -10), b, seed);
    canvas.drawPath(
      path,
      Paint()
        ..color = (blue ? const Color(0xFF2979FF) : const Color(0xFFB39DFF)).withValues(alpha: 0.6 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      b,
      9 * fade + 3,
      Paint()..color = (blue ? const Color(0xFF80D8FF) : const Color(0xFFE1D5FF)).withValues(alpha: 0.7 * fade),
    );
  }

  void _renderGroundStrike(Canvas canvas, Offset ground, BattleEffect e) {
    final fade = (1 - e.progress).clamp(0.0, 1.0);
    final top = ground.translate((e.seed % 21 - 10).toDouble(), -78);
    final path = _zigzag(top, ground, e.seed, jitter: 18, segments: 6);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF9FA8FF).withValues(alpha: 0.6 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(ground, 14 * (1 - fade) + 6, Paint()..color = Colors.white.withValues(alpha: 0.55 * fade));
  }

  // ------------------------------------------------------------ fire jet
  void _renderFireJet(Canvas canvas, Offset from, Offset to, BattleEffect e) {
    final p = e.progress;
    final fade = (1 - p).clamp(0.0, 1.0);
    final dir = to - from;
    final len = dir.distance;
    if (len < 2) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    // Mouth sits just in front of the hound, slightly above its centre.
    final mouth = from + u * 14 + const Offset(0, -6);
    final double reach = (len - 14) * (0.35 + 0.65 * math.min<double>(1.0, p * 3)); // jet shoots out fast
    final tip = mouth + u * reach;
    final double wide = 4.0 + 13.0 * math.min<double>(1.0, p * 2.5);
    final flick = 0.85 + 0.15 * math.sin(p * 60);
    Path cone(double w) => Path()
      ..moveTo(mouth.dx + n.dx * 2, mouth.dy + n.dy * 2)
      ..quadraticBezierTo(
        (mouth.dx + tip.dx) / 2 + n.dx * w, (mouth.dy + tip.dy) / 2 + n.dy * w,
        tip.dx + n.dx * w * 0.4, tip.dy + n.dy * w * 0.4,
      )
      ..lineTo(tip.dx - n.dx * w * 0.4, tip.dy - n.dy * w * 0.4)
      ..quadraticBezierTo(
        (mouth.dx + tip.dx) / 2 - n.dx * w, (mouth.dy + tip.dy) / 2 - n.dy * w,
        mouth.dx - n.dx * 2, mouth.dy - n.dy * 2,
      )
      ..close();
    canvas.drawPath(
      cone(wide * 1.5),
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.4 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(cone(wide), Paint()..color = const Color(0xFFE53900).withValues(alpha: 0.9 * fade * flick));
    canvas.drawPath(cone(wide * 0.66), Paint()..color = const Color(0xFFFF9800).withValues(alpha: fade));
    canvas.drawPath(cone(wide * 0.32), Paint()..color = const Color(0xFFFFEE58).withValues(alpha: fade));
    // Burst of fire where it lands.
    canvas.drawCircle(
      tip,
      6.0 + 10.0 * math.min<double>(1.0, p * 2),
      Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.55 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Sparks flying off.
    final spark = Paint()..color = const Color(0xFFFFCC80).withValues(alpha: fade);
    final rng = math.Random(e.seed);
    for (var i = 0; i < 7; i++) {
      final k = rng.nextDouble();
      final off = (rng.nextDouble() - 0.5) * wide * 2.2;
      canvas.drawCircle(mouth + u * (reach * k) + n * off, 1.3 + rng.nextDouble() * 1.4, spark);
    }
  }

  // ----------------------------------------------------------- explosion
  void _renderExplosion(Canvas canvas, Offset c, double r, BattleEffect e) {
    final p = e.progress;
    final fade = (1 - p).clamp(0.0, 1.0);
    final grow = Curves.easeOut.transform(p);
    canvas.drawCircle(
      c,
      r * (0.4 + 0.9 * grow),
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.5 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(c, r * (0.25 + 0.6 * grow), Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.8 * fade));
    canvas.drawCircle(c, r * (0.12 + 0.3 * grow), Paint()..color = const Color(0xFFFFF59D).withValues(alpha: fade));
    canvas.drawCircle(
      c,
      r * (0.5 + 1.1 * grow),
      Paint()
        ..color = const Color(0xFFFF8A65).withValues(alpha: 0.7 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Flying rock fragments.
    final rng = math.Random(e.seed);
    final rock = Paint()..color = const Color(0xFF3E2723).withValues(alpha: fade);
    final ember = Paint()..color = const Color(0xFFFFAB40).withValues(alpha: fade);
    for (var i = 0; i < 9; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final d = r * (0.3 + 1.0 * grow) * (0.6 + rng.nextDouble() * 0.6);
      final pos = c + Offset(math.cos(a) * d, math.sin(a) * d * 0.7 - 22 * math.sin(p * math.pi));
      canvas.drawCircle(pos, 2 + rng.nextDouble() * 2.5, i.isEven ? rock : ember);
    }
  }

  // ------------------------------------------------------------- helpers
  /// Optional hero-power art (assets/kenney/effects/*), or null if not shipped.
  ui.Image? _fxImage(String key) {
    final path = SpriteRegistry.paths[key];
    if (path == null) return null;
    final fileName = path.replaceFirst('assets/', '');
    return game.images.containsKey(fileName) ? game.images.fromCache(fileName) : null;
  }

  void _drawFx(Canvas canvas, ui.Image img, Rect dst, double opacity) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
  }

  /// Fire burst on the ground at [c], [size] px wide, k = 0..1 over its life.
  void _drawFireBurst(Canvas canvas, Offset c, double size, double k) {
    final fade = (1 - k).clamp(0.0, 1.0);
    final grow = 0.55 + 0.6 * Curves.easeOut.transform(k);
    final img = _fxImage('fx_fire_burst');
    if (img != null) {
      final w = size * grow;
      final h = w * img.height / img.width;
      _drawFx(canvas, img, Rect.fromLTWH(c.dx - w / 2, c.dy - h * 0.85, w, h), fade);
      return;
    }
    // Fallback: a bonfire of flame tongues licking upward (no PNG needed).
    canvas.drawCircle(
      c.translate(0, -12),
      size * 0.42 * grow,
      Paint()
        ..color = const Color(0xFFFF6A00).withValues(alpha: 0.30 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    const n = 9;
    for (var layer = 0; layer < _flameLayers.length; layer++) {
      for (var i = 0; i < n; i++) {
        final fx = i / (n - 1) - 0.5;
        final rnd = (math.sin(i * 12.9898) * 43758.5453).abs() % 1.0;
        final h = 0.55 + 0.45 * rnd;
        final L = size * 0.78 * h * grow;
        final W = size * 0.13 * (1.15 - fx.abs());
        final sway = math.sin(k * 20 + i * 1.9) * W * 0.6;
        _flameLayer(
          canvas,
          c.translate(fx * size * 0.62, -4),
          -math.pi / 2 + fx * 0.75 + math.sin(k * 16 + i) * 0.12,
          L,
          W,
          fade,
          sway,
          layer,
        );
      }
    }
  }

  // ------------------------------------------------------------ flames
  // Four stacked layers, outer -> inner: (colour, size scale, opacity). Drawing
  // a dark-red body, an orange middle, a yellow core and a pale-white heart
  // inside every tongue is what makes it read as real, hot fire.
  static const List<(int, double, double)> _flameLayers = [
    (0xFFC62800, 1.00, 0.60),
    (0xFFFF5A00, 0.84, 0.85),
    (0xFFFFA000, 0.62, 0.92),
    (0xFFFFF0B0, 0.36, 0.97),
  ];

  /// One flame tongue layer, base at [base], pointing along [angle].
  void _flameLayer(Canvas canvas, Offset base, double angle, double L, double W, double alpha, double sway, int layer) {
    if (alpha <= 0.01 || L < 2) return;
    final (color, scale, op) = _flameLayers[layer];
    final l = L * scale, w = W * scale, sw = sway * scale;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(l * 0.15, -w * 1.5, l * 0.62, -w * 1.0 + sw, l, sw)
      ..cubicTo(l * 0.62, w * 1.0 + sw, l * 0.15, w * 1.5, 0, 0)
      ..close();
    final paint = Paint()..color = Color(color).withValues(alpha: (op * alpha).clamp(0.0, 1.0));
    if (layer == 0) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// The breath itself: a stream of flame tongues pouring out of the mouth
  /// toward the target. Canvas is already translated + rotated so +x runs from
  /// the mouth to the target. Particles keep flowing outward, flicker and fade.
  void _drawFlameStream(Canvas canvas, double dist, double len, double p, double fade, int seed) {
    const n = 20;
    final rng = math.Random(seed);
    final phase = List<double>.generate(n, (_) => rng.nextDouble());
    final off = List<double>.generate(n, (_) => rng.nextDouble() - 0.5);

    // Soft heat glow under the whole jet.
    canvas.drawLine(
      Offset.zero,
      Offset(len, 0),
      Paint()
        ..color = const Color(0xFFFF8A00).withValues(alpha: 0.24 * fade)
        ..strokeWidth = 22 + 22 * (len / dist)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final us = List<double>.generate(n, (i) => (p * 2.6 + i / n + phase[i] * 0.12) % 1.0);
    for (var layer = 0; layer < _flameLayers.length; layer++) {
      for (var i = 0; i < n; i++) {
        final u = us[i];
        final spread = 4 + u * 26;
        final y = off[i] * spread + math.sin(p * 28 + i * 1.7) * (2 + 5 * u);
        final L = 30 + 52 * u;
        final W = 5 + 13 * u;
        final a = fade * math.min(1.0, u * 7) * (1 - math.pow(u, 3).toDouble());
        _flameLayer(
          canvas,
          Offset(u * len, y),
          off[i] * 0.6 + math.sin(p * 21 + i) * 0.14,
          L,
          W,
          a,
          math.sin(p * 35 + i * 2.3) * W * 0.55,
          layer,
        );
      }
    }
    // Flying sparks / embers.
    final spark = Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9 * fade);
    for (var i = 0; i < 9; i++) {
      final u = (p * 1.7 + i * 0.113 + phase[i] * 0.3) % 1.0;
      final y = off[i] * (14 + u * 44) + math.sin(p * 18 + i) * 4;
      canvas.drawCircle(Offset(u * len, y), 1.4 + (i % 3) * 0.7, spark);
    }
  }

  // ------------------------------------------------------------ fire breath
  // Unit sprites are drawn in a 30px box, centred on the unit's ground point
  // (UnitComponent), and the Phoenix hovers 26px above it. The flame must start
  // at the creature's MOUTH inside that box -- not at a fixed point far above
  // it, which made the fire look like it was falling from the sky.
  // Dragon / Phoenix are drawn big (UnitData.renderSizeFor) and flip to face
  // their target, so the mouth sits on the side the creature is looking at.
  Offset _breathMouth(Offset ground, BattleEffect e, double t) {
    final box = e.creatureSize;
    final side = e.facingLeft ? -1.0 : 1.0;
    if (e.airborne) {
      // Phoenix: the beak sits at the upper front of the sprite.
      final hover = UnitData.hoverFor(UnitType.phoenix);
      final bob = math.sin(t * 3.2) * 3.0;
      return ground.translate(side * box * 0.27, -hover + bob - box * 0.15);
    }
    // Dragon: the mouth is at the front edge, just above the middle.
    return ground.translate(side * box * 0.46, -box * 0.10 - e.hover);
  }

  /// Dragon / Phoenix: a jet of flame that grows out of the MOUTH, streams to
  /// the target, then fades while a fire burst blooms on the enemy.
  void _renderFireBreath(Canvas canvas, Offset mouth, Offset target, BattleEffect e) {
    final p = e.progress;
    final fade = p > 0.7 ? (1 - p) / 0.3 : 1.0;
    final grow = Curves.easeOut.transform(math.min(1.0, p / 0.3));
    final dx = target.dx - mouth.dx;
    final dy = target.dy - mouth.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 4) return;
    final angle = math.atan2(dy, dx);
    final len = dist * grow;
    final img = _fxImage('fx_fire_breath');

    canvas.save();
    canvas.translate(mouth.dx, mouth.dy);
    canvas.rotate(angle);
    if (img != null) {
      // Art points right, its left-middle sits on the mouth.
      final hh = (len * 0.38).clamp(34.0, 110.0);
      final wobble = 1 + 0.06 * math.sin(p * 40);
      _drawFx(canvas, img, Rect.fromLTWH(0, -hh * wobble / 2, len, hh * wobble), fade);
    } else {
      _drawFlameStream(canvas, dist, len, p, fade, e.seed);
    }
    canvas.restore();

    if (p > 0.22) _drawFireBurst(canvas, target, 96, ((p - 0.22) / 0.78).clamp(0.0, 1.0));
  }

  // ------------------------------------------------------------ sky fire
  /// Elf Prince: a column of fire falls out of the sky onto the ENEMY at
  /// [ground] ([e.radius] seconds of falling), then explodes there.
  void _renderSkyFire(Canvas canvas, Offset ground, BattleEffect e) {
    final fallTime = math.max(0.2, e.radius);
    final tFall = fallTime / e.life; // fraction of the effect spent falling
    final p = e.progress;
    final img = _fxImage('fx_sky_fire');
    if (p < tFall) {
      final k = Curves.easeIn.transform(p / tFall);
      final top = ground.translate(0, -300);
      final head = Offset.lerp(top, ground, k)!;
      // Target ring on the ground so you can see where it will land.
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: 70 * k + 16, height: 30 * k + 8),
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      if (img != null) {
        const w = 64.0;
        final h = w * img.height / img.width;
        _drawFx(canvas, img, Rect.fromLTWH(head.dx - w / 2, head.dy - h, w, h), 1.0);
      } else {
        final streak = Path()
          ..moveTo(head.dx - 9, head.dy - 90)
          ..lineTo(head.dx + 9, head.dy - 90)
          ..lineTo(head.dx + 5, head.dy)
          ..lineTo(head.dx - 5, head.dy)
          ..close();
        canvas.drawPath(
          streak,
          Paint()
            ..color = const Color(0xFFFF6D00).withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(streak, Paint()..color = const Color(0xFFFFA000).withValues(alpha: 0.8));
        canvas.drawCircle(head, 14, Paint()..color = const Color(0xFFFF7043));
        canvas.drawCircle(head, 9, Paint()..color = const Color(0xFFFFCA28));
        canvas.drawCircle(head, 4, Paint()..color = const Color(0xFFFFF9C4));
      }
    } else {
      final k = ((p - tFall) / (1 - tFall)).clamp(0.0, 1.0);
      _drawFireBurst(canvas, ground, 130, k);
    }
  }

  // ---------------------------------------------------------- magic burst
  /// Magician: the magic ball bursts into a glowing green-gold flower of light.
  void _renderMagicBurst(Canvas canvas, Offset c, double radius, BattleEffect e) {
    final k = e.progress;
    final fade = (1 - k).clamp(0.0, 1.0);
    final grow = 0.5 + 0.7 * Curves.easeOut.transform(k);
    final img = _fxImage('fx_magic_burst');
    final size = radius * 1.6 * grow;
    if (img != null) {
      final h = size * img.height / img.width;
      _drawFx(canvas, img, Rect.fromLTWH(c.dx - size / 2, c.dy - h * 0.6, size, h), fade);
      return;
    }
    final center = c.translate(0, -14);
    canvas.drawCircle(center, size * 0.55, Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.35 * fade));
    canvas.drawCircle(
      center,
      size * 0.5,
      Paint()
        ..color = const Color(0xFFFFF59D).withValues(alpha: 0.9 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, size * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.9 * fade));
    final rng = math.Random(e.seed);
    final spark = Paint()..color = const Color(0xFFFFF176).withValues(alpha: fade);
    for (var i = 0; i < 9; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final d = size * (0.25 + 0.4 * k) * (0.7 + rng.nextDouble() * 0.6);
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * d, 2 + rng.nextDouble() * 2, spark);
    }
  }

  // ---------------------------------------------------------- storm cast
  /// Storm Caller: he lifts his hand, a violet-white orb swells in the palm,
  /// then a stream of storm energy shoots to where the storm forms.
  void _renderStormCast(Canvas canvas, Offset caster, Offset target, BattleEffect e) {
    final p = e.progress;
    final fade = p > 0.75 ? (1 - p) / 0.25 : 1.0;
    // Raised hand, up and in front of the caster (he faces left).
    final hand = caster.translate(-16, -40 - 6 * math.sin(p * math.pi));
    final orbR = (4 + 9 * math.min<double>(1.0, p * 2.5)) * fade;
    canvas.drawCircle(
      hand,
      orbR * 2.2,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.45 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(hand, orbR, Paint()..color = const Color(0xFFB39DFF).withValues(alpha: 0.95 * fade));
    canvas.drawCircle(hand, orbR * 0.5, Paint()..color = Colors.white.withValues(alpha: fade));
    // Crackling sparks orbiting the palm.
    final rng = math.Random(e.seed);
    final spark = Paint()
      ..color = const Color(0xFFE1D5FF).withValues(alpha: fade)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * 2 * math.pi + p * 12;
      final r1 = orbR * 1.1;
      final r2 = orbR * (1.7 + rng.nextDouble() * 0.8);
      canvas.drawLine(hand + Offset(math.cos(a), math.sin(a)) * r1, hand + Offset(math.cos(a), math.sin(a)) * r2, spark);
    }
    // After the wind-up the energy flies from the hand to the storm spot.
    if (p > 0.3) {
      final k = ((p - 0.3) / 0.35).clamp(0.0, 1.0);
      final tip = Offset.lerp(hand, target.translate(0, -70), k)!;
      final path = _zigzag(hand, tip, e.seed + (p * 6).floor() * 131, jitter: 10, segments: 6);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.6 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  // --------------------------------------------------------- sword slash
  /// Storm Knight: a big crescent slash arcs across the target (castle or
  /// soldier), with a crackle of blue-white sparks.
  void _renderSwordSlash(Canvas canvas, Offset from, Offset target, BattleEffect e) {
    final p = e.progress;
    final fade = (1 - p).clamp(0.0, 1.0);
    final sweep = Curves.easeOut.transform(math.min<double>(1.0, p * 2.2));
    final c = target.translate(0, -8);
    const r = 26.0;
    // Slash arc: sweeps from upper-right down to lower-left (knight faces left).
    const start = -math.pi * 0.15;
    final arc = math.pi * 0.95 * sweep;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      start,
      arc,
      false,
      Paint()
        ..color = const Color(0xFF82B1FF).withValues(alpha: 0.55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      rect,
      start,
      arc,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    final rng = math.Random(e.seed);
    final spark = Paint()..color = const Color(0xFFBBDEFB).withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final a = start + rng.nextDouble() * arc;
      final d = r * (0.9 + rng.nextDouble() * 0.9) + 8 * p;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, 1.2 + rng.nextDouble() * 1.6, spark);
    }
  }

  // ---------------------------------------------------------------- heal
  void _renderHeal(Canvas canvas, Offset c, double r, BattleEffect e) {
    final p = e.progress;
    final fade = (1 - p).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2 * (0.3 + 0.7 * p), height: r * 1.2 * (0.3 + 0.7 * p)),
      Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2 * p, height: r * 1.2 * p),
      Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.18 * fade),
    );
    final plus = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: fade)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * 2 * math.pi;
      final pos = c + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.3 - 26 * p);
      canvas.drawLine(pos.translate(-4, 0), pos.translate(4, 0), plus);
      canvas.drawLine(pos.translate(0, -4), pos.translate(0, 4), plus);
    }
  }

  // ---------------------------------------------------------------- bark
  void _renderBark(Canvas canvas, Offset c, BattleEffect e) {
    final p = e.progress;
    final fade = p > 0.7 ? (1 - p) / 0.3 : 1.0;
    final pos = c.translate(-6, -34 - 8 * p);
    final tp = TextPainter(
      text: TextSpan(
        text: 'GRAWR!',
        style: TextStyle(
          color: const Color(0xFFFFCA28).withValues(alpha: fade),
          fontSize: 12.0 + 4.0 * math.min<double>(1.0, p * 4),
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: const Color(0xFFB71C1C).withValues(alpha: fade), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-0.12);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}