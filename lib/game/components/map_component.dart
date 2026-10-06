// Renders the battlefield backdrop: a continuously looping day/night sky
// (day -> dusk -> night -> dawn -> day, forever — see
// KingdomWarsGame.dayNightClock for the clock all of this reads from) with
// the sun or moon arcing across it, drifting clouds by day, twinkling stars
// by night, then the tiled ground below. Fills the ACTUAL screen size
// (game.size, which Flame keeps in sync with the device/window on every
// resize or rotation) rather than a fixed size derived from the lane length
// — using the lane-derived size here left a raw, unpainted (black) strip on
// any screen wider than the lane itself.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/level.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';
import 'scenery_painter.dart';

class MapComponent extends PositionComponent {
  final KingdomWarsGame game;
  static const double tileSize = 96.0;

  // Fixed cloud "slots" that drift left-to-right and wrap around, each with
  // its own height/speed/size so they don't read as one repeating stamp.
  static const List<_Cloud> _clouds = [
    _Cloud(startFrac: 0.05, heightFrac: 0.18, scale: 1.0, speed: 6),
    _Cloud(startFrac: 0.4, heightFrac: 0.3, scale: 1.4, speed: 4),
    _Cloud(startFrac: 0.7, heightFrac: 0.12, scale: 0.8, speed: 7.5),
    _Cloud(startFrac: 0.9, heightFrac: 0.4, scale: 1.1, speed: 5),
  ];

  static const List<Offset> _starSlots = [
    Offset(0.06, 0.15), Offset(0.15, 0.35), Offset(0.22, 0.08),
    Offset(0.33, 0.28), Offset(0.42, 0.12), Offset(0.5, 0.4),
    Offset(0.58, 0.18), Offset(0.68, 0.3), Offset(0.75, 0.1),
    Offset(0.82, 0.36), Offset(0.9, 0.2), Offset(0.96, 0.42),
    Offset(0.12, 0.5), Offset(0.6, 0.05), Offset(0.87, 0.5),
  ];

  // Starting x-fraction for each falling snowflake in a Frozen Pass battle —
  // spread across the full screen width, each later drifting down at its
  // own speed (see _drawSnow). Only ever drawn during the frozenPass
  // chapter, and even then only in flurries (see _snowIntensity) rather
  // than falling nonstop for the whole battle.
  static const List<double> _snowXFracs = [
    0.03, 0.09, 0.14, 0.2, 0.27, 0.33, 0.39, 0.46, 0.52, 0.58,
    0.64, 0.7, 0.76, 0.82, 0.88, 0.94, 0.11, 0.23, 0.61, 0.79,
  ];

  late final SceneryPainter _scenery = SceneryPainter(game);

  MapComponent({required this.game}) : super(priority: -10);

  @override
  void render(Canvas canvas) {
    final backgroundTile =
        game.provider.gameEngine.activeBattle?.level?.backgroundTile ?? 'tile_grass';
    final assetPath = SpriteRegistry.pathFor(backgroundTile);
    final fileName = assetPath.replaceFirst('assets/', '');
    final image = game.images.containsKey(fileName) ? game.images.fromCache(fileName) : null;

    // Fills the ACTUAL screen size rather than a fixed size derived from
    // the lane length, so there's never an unpainted (black) strip on a
    // screen wider or taller than the playable lane itself.
    final playFieldWidth = game.size.x;
    final playFieldHeight = game.size.y;
    final groundTop = game.groundTop;
    final daylight = game.daylight;

    // Thunderstorm chapter: permanent dark storm (no day/night cycle) with
    // rain, lightning and burning ground fires. Handled entirely separately.
    if (_isStorm) {
      _renderStorm(canvas, playFieldWidth, playFieldHeight, groundTop, image);
      return;
    }

    _drawSky(canvas, playFieldWidth, groundTop, daylight);
    _drawCelestialBody(canvas, playFieldWidth, groundTop, daylight);
    if (daylight > 0.05) _drawClouds(canvas, playFieldWidth, groundTop, daylight);
    if (daylight < 0.95) _drawStars(canvas, playFieldWidth, groundTop, daylight);
    _scenery.drawMountains(canvas, playFieldWidth, groundTop);
    canvas.drawLine(
      Offset(0, groundTop),
      Offset(playFieldWidth, groundTop),
      Paint()
        ..color = AppColors.royalGold.withValues(alpha: 0.22 + 0.18 * daylight)
        ..strokeWidth = 2,
    );

    // Falling snow (Frozen Pass only, and even then only in flurries) is
    // drawn here — after the sky/sun/clouds/stars but before the ground
    // tiles/night tint below — so it reads as weather in front of the sky
    // rather than under it, regardless of whether the ground-tile image
    // loaded (the branch right below can return early on a missing asset).
    _drawSnow(canvas, playFieldWidth, playFieldHeight);

    final nightTint = (1 - daylight) * 0.45;
    if (image == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, groundTop, playFieldWidth, playFieldHeight - groundTop),
        Paint()..color = Color.lerp(AppColors.deepPurple, Colors.black, nightTint)!,
      );
    } else {
      final sprite = Sprite(image);
      for (double y = groundTop; y < playFieldHeight; y += tileSize) {
        for (double x = 0; x < playFieldWidth; x += tileSize) {
          sprite.render(
            canvas,
            position: Vector2(x, y),
            size: Vector2.all(tileSize),
          );
        }
      }
      if (nightTint > 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(0, groundTop, playFieldWidth, playFieldHeight - groundTop),
          Paint()..color = Colors.black.withValues(alpha: nightTint),
        );
      }
    }

    // Scenery on top of the ground (each piece applies its own night tint).
    _scenery.drawGrass(canvas, playFieldWidth, playFieldHeight, groundTop);
    _scenery.drawTrees(canvas, playFieldWidth, playFieldHeight, groundTop);
  }

  void _drawSky(Canvas canvas, double w, double skyHeight, double daylight) {
    const dayTop = Color(0xFF6FB7E8);
    const dayBottom = Color(0xFFCDEBFA);
    const duskTop = Color(0xFF3A4C7A);
    const duskBottom = Color(0xFFE8926B);
    const nightTop = Color(0xFF060A1F);
    const nightBottom = Color(0xFF1B2547);

    Color top, bottom;
    if (daylight > 0.5) {
      final t = (daylight - 0.5) * 2;
      top = Color.lerp(duskTop, dayTop, t)!;
      bottom = Color.lerp(duskBottom, dayBottom, t)!;
    } else {
      final t = daylight * 2;
      top = Color.lerp(nightTop, duskTop, t)!;
      bottom = Color.lerp(nightBottom, duskBottom, t)!;
    }

    final rect = Rect.fromLTWH(0, 0, w, skyHeight);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  void _drawCelestialBody(Canvas canvas, double w, double skyHeight, double daylight) {
    final pos = game.sunMoonPosition(w, skyHeight);
    final center = Offset(pos.x, pos.y);
    final isSun = game.isDaySegment;
    final glow = math.sin(game.bodyProgress * math.pi).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      isSun ? 46 : 30,
      Paint()
        ..color = (isSun ? const Color(0xFFFFE9A8) : const Color(0xFFDDE6F5)).withValues(alpha: 0.2 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    if (isSun) {
      // The sun's own color eases through a sunrise -> midday -> sunset
      // gradient across the day instead of staying one fixed shade: warm
      // orange-red low on the horizon at either end of the day, brightening
      // gradually to a pale gold-white overhead at noon. `noonness` is 0 at
      // sunrise/sunset and 1 at the midpoint of the day (bodyProgress 0.5).
      const horizonColor = Color(0xFFFF7F3F); // warm sunrise/sunset orange
      const noonColor = Color(0xFFFFF3C4); // bright midday gold-white
      final noonness = (1 - (2 * (game.bodyProgress - 0.5).abs())).clamp(0.0, 1.0);
      final sunColor = Color.lerp(horizonColor, noonColor, noonness)!;
      // A soft warm halo lingers around the low morning/evening sun and
      // fades out as it climbs toward noon.
      canvas.drawCircle(center, 34, Paint()..color = horizonColor.withValues(alpha: 0.28 * (1 - noonness)));
      canvas.drawCircle(center, 22, Paint()..color = sunColor);
    } else {
      canvas.drawCircle(center, 16, Paint()..color = const Color(0xFFF1F4FA));
      // Crescent: overlay a sky-colored circle offset to one side.
      canvas.drawCircle(
        center.translate(7, -4),
        14,
        Paint()..color = Color.lerp(const Color(0xFF060A1F), const Color(0xFF3A4C7A), daylight)!,
      );
    }
  }

  void _drawClouds(Canvas canvas, double w, double skyHeight, double daylight) {
    final t = game.dayNightClock;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75 * daylight);
    for (final cloud in _clouds) {
      final span = w + 160;
      final travel = ((cloud.startFrac * span) + t * cloud.speed) % span - 80;
      final cy = skyHeight * cloud.heightFrac;
      _drawCloudPuff(canvas, travel, cy, cloud.scale, paint);
    }
  }

  void _drawCloudPuff(Canvas canvas, double cx, double cy, double scale, Paint paint) {
    for (final o in const [Offset(-22, 4), Offset(-6, -6), Offset(14, 0), Offset(30, 6)]) {
      canvas.drawCircle(Offset(cx + o.dx * scale, cy + o.dy * scale), 16 * scale, paint);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 6 * scale), width: 80 * scale, height: 20 * scale),
      paint,
    );
  }

  void _drawStars(Canvas canvas, double w, double skyHeight, double daylight) {
    final opacity = (1 - daylight).clamp(0.0, 1.0);
    final t = game.dayNightClock;
    for (int i = 0; i < _starSlots.length; i++) {
      final slot = _starSlots[i];
      final twinkle = 0.5 + 0.5 * math.sin(t * 2 + i * 1.7);
      canvas.drawCircle(
        Offset(slot.dx * w, slot.dy * skyHeight),
        1.6,
        Paint()..color = Colors.white.withValues(alpha: opacity * (0.4 + 0.6 * twinkle)),
      );
    }
  }

  /// 0..1 how hard it's currently snowing. Only ever non-zero during the
  /// Frozen Pass chapter, and even then it isn't constant: a slow repeating
  /// cycle alternates a flurry with a calm stretch, fading in/out at each
  /// transition instead of switching abruptly, so snow visibly comes and
  /// goes over the course of a battle rather than falling the whole time.
  double _snowIntensity() {
    final chapter = game.provider.gameEngine.activeBattle?.level?.chapter;
    if (chapter != Chapter.frozenPass) return 0.0;

    const cycleSeconds = 50.0; // one flurry + one calm stretch
    const activeShare = 0.4; // snows for ~40% of each cycle
    const fade = 0.08; // fraction of the cycle spent easing in/out
    final phase = (game.dayNightClock % cycleSeconds) / cycleSeconds;
    if (phase >= activeShare) return 0.0;
    if (phase < fade) return phase / fade;
    if (phase > activeShare - fade) return (activeShare - phase) / fade;
    return 1.0;
  }

  void _drawSnow(Canvas canvas, double w, double h) {
    final intensity = _snowIntensity();
    if (intensity <= 0.01) return;

    final t = game.dayNightClock;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.8 * intensity);
    for (int i = 0; i < _snowXFracs.length; i++) {
      // Each flake has its own fall speed and a gentle side-to-side drift so
      // the flurry doesn't read as identical flakes falling in lockstep.
      final fallSpeed = 30.0 + (i % 5) * 8;
      final drift = math.sin(t * 0.7 + i * 1.3) * 12;
      final y = (t * fallSpeed + i * 53) % (h + 20) - 10;
      final x = (_snowXFracs[i] * w + drift) % w;
      canvas.drawCircle(Offset(x, y), 2.0 + (i % 3) * 0.6, paint);
    }
  }
  // ---------------------------------------------------------------------
  // THUNDERSTORM chapter backdrop
  // ---------------------------------------------------------------------
  bool get _isStorm =>
      game.provider.gameEngine.activeBattle?.level?.chapter == Chapter.thunderstorm;

  // Fixed fire spots along the ground (x as a fraction of screen width) and
  // rain drop start columns, so nothing is random per-frame (no flicker of
  // positions, only of flame shape).
  static const List<double> _fireXFracs = [
    0.04, 0.13, 0.22, 0.31, 0.43, 0.52, 0.61, 0.72, 0.81, 0.9, 0.97,
  ];

  /// 0..1 lightning flash strength. Every ~6.5s a strike: a bright flash,
  /// a short dark gap, then a weaker second flicker — like real lightning.
  double _lightningFlash() {
    const cycle = 6.5;
    final t = game.dayNightClock % cycle;
    double f = 0;
    if (t < 0.10) f = 1.0 - t / 0.10;
    if (t > 0.18 && t < 0.32) f = 0.7 * (1.0 - (t - 0.18) / 0.14);
    return f.clamp(0.0, 1.0);
  }

  void _renderStorm(Canvas canvas, double w, double h, double groundTop, ui.Image? tile) {
    final t = game.dayNightClock;
    final flash = _lightningFlash();

    // --- Sky: near-black purple, glowing red-orange where fire lights the horizon.
    final skyRect = Rect.fromLTWH(0, 0, w, groundTop);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF04050D), Color(0xFF1A1030), Color(0xFF5A1A22)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(skyRect),
    );

    // --- Heavy storm clouds rolling across.
    final cloudPaint = Paint()..color = const Color(0xFF0B0B18).withValues(alpha: 0.85);
    for (int i = 0; i < 6; i++) {
      final span = w + 240;
      final cx = ((i * 0.19 * span) + t * (10 + i * 2.5)) % span - 120;
      final cy = groundTop * (0.10 + (i % 3) * 0.14);
      final sc = 1.8 + (i % 3) * 0.5;
      _drawCloudPuff(canvas, cx, cy, sc, cloudPaint);
    }

    // --- Dark mountains on the horizon.
    _scenery.drawMountains(canvas, w, groundTop);

    // --- Lightning bolt (only during the flash window).
    if (flash > 0.02) {
      final strike = (t / 6.5).floor();
      final rnd = math.Random(strike * 7919 + 13);
      var x = w * (0.15 + rnd.nextDouble() * 0.7);
      var y = 0.0;
      final bolt = Path()..moveTo(x, y);
      while (y < groundTop) {
        y += 18 + rnd.nextDouble() * 22;
        x += (rnd.nextDouble() - 0.5) * 46;
        bolt.lineTo(x, math.min(y, groundTop));
      }
      canvas.drawPath(
        bolt,
        Paint()
          ..color = const Color(0xFFB39DFF).withValues(alpha: 0.6 * flash)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        bolt,
        Paint()
          ..color = Colors.white.withValues(alpha: flash)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // --- Horizon line.
    canvas.drawLine(
      Offset(0, groundTop),
      Offset(w, groundTop),
      Paint()
        ..color = const Color(0xFFFF6A00).withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );

    // --- Ground: tile art if shipped, otherwise a procedural charred field.
    final groundRect = Rect.fromLTWH(0, groundTop, w, h - groundTop);
    if (tile != null) {
      final sprite = Sprite(tile);
      for (double y = groundTop; y < h; y += tileSize) {
        for (double x = 0; x < w; x += tileSize) {
          sprite.render(canvas, position: Vector2(x, y), size: Vector2.all(tileSize));
        }
      }
      canvas.drawRect(groundRect, Paint()..color = Colors.black.withValues(alpha: 0.25));
    } else {
      canvas.drawRect(
        groundRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1A1E), Color(0xFF15090D)],
          ).createShader(groundRect),
      );
      // Glowing lava-like cracks in the scorched earth.
      final crack = Paint()
        ..color = const Color(0xFFFF5A00).withValues(alpha: 0.35 + 0.15 * math.sin(t * 3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (int i = 0; i < 9; i++) {
        final sx = w * (0.05 + i * 0.115);
        final sy = groundTop + (h - groundTop) * (0.25 + (i % 4) * 0.2);
        final p = Path()
          ..moveTo(sx, sy)
          ..lineTo(sx + 16, sy + 7)
          ..lineTo(sx + 30, sy - 3)
          ..lineTo(sx + 48, sy + 6);
        canvas.drawPath(p, crack);
      }
    }

    // --- Scorched trees and dry grass.
    _scenery.drawGrass(canvas, w, h, groundTop);
    _scenery.drawTrees(canvas, w, h, groundTop);

    // --- Fires burning along the ground (on the horizon and near the bottom).
    for (int i = 0; i < _fireXFracs.length; i++) {
      final fx = _fireXFracs[i] * w;
      _drawFlame(canvas, fx, groundTop + 10, 16.0 + (i % 3) * 5.0, t, i);
      if (i.isEven) {
        _drawFlame(canvas, fx + 26, h - 10, 20.0 + (i % 2) * 6.0, t, i + 5);
      }
    }

    // --- Rising embers.
    final ember = Paint();
    for (int i = 0; i < 24; i++) {
      final speed = 22.0 + (i % 5) * 9;
      final y = h - ((t * speed + i * 41) % (h - groundTop + 30));
      final x = (w * ((i * 0.0417) % 1.0)) + math.sin(t * 1.3 + i) * 10;
      ember.color = const Color(0xFFFFA726).withValues(alpha: 0.35 + 0.4 * ((i % 3) / 3));
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.5, ember);
    }

    // --- Rain: fast slanted streaks across the whole screen.
    final rain = Paint()
      ..color = const Color(0xFFBBD0FF).withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 70; i++) {
      final speed = 420.0 + (i % 6) * 60;
      final y = (t * speed + i * 37) % (h + 40) - 20;
      final x = ((i * 0.0143 * w * 7) % w) - (y * 0.18);
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 16), rain);
    }

    // --- Darkness over everything, then the lightning flash on top.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.black.withValues(alpha: 0.18));
    if (flash > 0.02) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFFDDE4FF).withValues(alpha: 0.38 * flash),
      );
    }
  }

  void _drawFlame(Canvas canvas, double x, double baseY, double size, double t, int seed) {
    final flick = 0.75 + 0.25 * math.sin(t * 9 + seed * 1.9);
    final sway = math.sin(t * 5 + seed) * size * 0.12;
    // Soft glow.
    canvas.drawCircle(
      Offset(x, baseY - size * 0.5),
      size * 1.5,
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.22 * flick)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    Path teardrop(double s) => Path()
      ..moveTo(x - s * 0.55, baseY)
      ..quadraticBezierTo(x - s * 0.7, baseY - s * 0.8, x + sway, baseY - s * 1.7 * flick)
      ..quadraticBezierTo(x + s * 0.7, baseY - s * 0.8, x + s * 0.55, baseY)
      ..close();
    canvas.drawPath(teardrop(size), Paint()..color = const Color(0xFFE53900).withValues(alpha: 0.92));
    canvas.drawPath(teardrop(size * 0.66), Paint()..color = const Color(0xFFFF9800));
    canvas.drawPath(teardrop(size * 0.34), Paint()..color = const Color(0xFFFFEE58));
  }
}

class _Cloud {
  final double startFrac;
  final double heightFrac;
  final double scale;
  final double speed;
  const _Cloud({
    required this.startFrac,
    required this.heightFrac,
    required this.scale,
    required this.speed,
  });
}
