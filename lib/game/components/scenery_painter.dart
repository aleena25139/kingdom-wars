// Battlefield scenery: MOUNTAINS on the horizon, TREES standing along the
// horizon line, and GRASS tufts scattered over the ground. Used by
// MapComponent (which calls drawMountains / drawTrees / drawGrass at the right
// moments in its paint order).
//
// Every piece is OPTIONAL art: if a PNG from assets/kenney/scenery/ is present
// it is used, otherwise a simple procedural version is painted, so the game
// always has mountains/trees/grass even before the final art is dropped in.
// File names are listed in SpriteRegistry ('scenery_*' keys) and in
// assets/kenney/scenery/README.txt.
//
// Layout is deterministic (seeded), so nothing jumps around between frames.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/level.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';

enum _Biome { green, snow, burnt, storm }

class _Theme {
  final String mountainKey;
  final List<String> treeKeys;
  final List<String> grassKeys;
  final Color farMountain;
  final Color nearMountain;
  final Color? snowCap;
  final Color leaf;
  final Color trunk;
  final Color tuft;
  const _Theme({
    required this.mountainKey,
    required this.treeKeys,
    required this.grassKeys,
    required this.farMountain,
    required this.nearMountain,
    required this.snowCap,
    required this.leaf,
    required this.trunk,
    required this.tuft,
  });
}

const Map<_Biome, _Theme> _themes = {
  _Biome.green: _Theme(
    mountainKey: 'scenery_mountains_green',
    treeKeys: ['scenery_tree_green_1', 'scenery_tree_green_2', 'scenery_tree_green_3'],
    grassKeys: ['scenery_grass_1', 'scenery_grass_2', 'scenery_grass_3'],
    farMountain: Color(0xFF8CA7C7),
    nearMountain: Color(0xFF5F8A7A),
    snowCap: Color(0xFFF4F8FC),
    leaf: Color(0xFF3F8F43),
    trunk: Color(0xFF6D4C41),
    tuft: Color(0xFF58B04F),
  ),
  _Biome.snow: _Theme(
    mountainKey: 'scenery_mountains_snow',
    treeKeys: ['scenery_tree_snow_1', 'scenery_tree_snow_2'],
    grassKeys: ['scenery_grass_snow'],
    farMountain: Color(0xFFB4C9E0),
    nearMountain: Color(0xFF8BA3C0),
    snowCap: Color(0xFFFFFFFF),
    leaf: Color(0xFF2F5D50),
    trunk: Color(0xFF5D4037),
    tuft: Color(0xFFDDE9F2),
  ),
  _Biome.burnt: _Theme(
    mountainKey: 'scenery_mountains_lava',
    treeKeys: ['scenery_tree_burnt_1', 'scenery_tree_burnt_2'],
    grassKeys: ['scenery_grass_dry'],
    farMountain: Color(0xFF6B3030),
    nearMountain: Color(0xFF3F1C1C),
    snowCap: null,
    leaf: Color(0xFF2A1A14),
    trunk: Color(0xFF2A1A14),
    tuft: Color(0xFF7A5A30),
  ),
  _Biome.storm: _Theme(
    mountainKey: 'scenery_mountains_storm',
    treeKeys: ['scenery_tree_burnt_1', 'scenery_tree_burnt_2'],
    grassKeys: ['scenery_grass_dry'],
    farMountain: Color(0xFF2A2444),
    nearMountain: Color(0xFF16122A),
    snowCap: null,
    leaf: Color(0xFF1E1410),
    trunk: Color(0xFF1E1410),
    tuft: Color(0xFF4A3A36),
  ),
};

class _Plant {
  final double xFrac; // 0..1 across the screen width
  final double depth; // 0 = on the horizon (far), 1 = nearer the viewer
  final int variant;
  final bool flip;
  final double scale;
  final double phase;
  const _Plant(this.xFrac, this.depth, this.variant, this.flip, this.scale, this.phase);
}

class SceneryPainter {
  final KingdomWarsGame game;
  SceneryPainter(this.game);

  late final List<_Plant> _trees = _layout(seed: 7, count: 26, skip: 0.22);
  late final List<_Plant> _tufts = _layout(seed: 99, count: 70, skip: 0.0);

  static List<_Plant> _layout({required int seed, required int count, required double skip}) {
    final rnd = math.Random(seed);
    final out = <_Plant>[];
    for (var i = 0; i < count; i++) {
      if (rnd.nextDouble() < skip) continue;
      out.add(_Plant(
        ((i + rnd.nextDouble() * 0.8) / count).clamp(0.0, 1.0),
        rnd.nextDouble(),
        rnd.nextInt(1000),
        rnd.nextBool(),
        0.8 + rnd.nextDouble() * 0.4,
        rnd.nextDouble() * 6.28,
      ));
    }
    return out;
  }

  _Biome get _biome {
    switch (game.provider.gameEngine.activeBattle?.level?.chapter) {
      case Chapter.frozenPass:
        return _Biome.snow;
      case Chapter.volcanicRidge:
      case Chapter.dragonsLair:
        return _Biome.burnt;
      case Chapter.thunderstorm:
        return _Biome.storm;
      default:
        return _Biome.green;
    }
  }

  _Theme get _theme => _themes[_biome]!;

  /// How much to darken scenery that sticks up above the ground overlay.
  double get _tint => _biome == _Biome.storm ? 0.4 : (1 - game.daylight) * 0.45;

  ui.Image? _image(String key) {
    final path = SpriteRegistry.paths[key];
    if (path == null) return null;
    final fileName = path.replaceFirst('assets/', '');
    return game.images.containsKey(fileName) ? game.images.fromCache(fileName) : null;
  }

  /// Keys from [keys] whose art actually shipped.
  List<ui.Image> _available(List<String> keys) =>
      [for (final k in keys) if (_image(k) != null) _image(k)!];

  Paint _imagePaint() {
    final t = _tint;
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = t > 0.01 ? ColorFilter.mode(Colors.black.withValues(alpha: t), BlendMode.srcATop) : null;
  }

  Color _dim(Color c) => Color.lerp(c, Colors.black, _tint)!;

  // ---------------------------------------------------------------- mountains
  void drawMountains(Canvas canvas, double w, double groundTop) {
    final theme = _theme;
    final img = _image(theme.mountainKey);
    if (img == null) {
      _proceduralMountains(canvas, w, groundTop, theme);
      return;
    }
    // Scale to a fraction of the sky height; tile across the width, mirroring
    // every other copy so the joins are invisible even if the art isn't
    // perfectly seamless.
    final h = (groundTop * 0.62).clamp(60.0, 280.0);
    final tileW = h * img.width / img.height;
    final paint = _imagePaint();
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    var i = 0;
    for (double x = 0; x < w; x += tileW, i++) {
      canvas.save();
      if (i.isOdd) {
        canvas.translate(x + tileW, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(img, src, Rect.fromLTWH(0, groundTop + 2 - h, tileW, h), paint);
      } else {
        canvas.drawImageRect(img, src, Rect.fromLTWH(x, groundTop + 2 - h, tileW, h), paint);
      }
      canvas.restore();
    }
  }

  void _proceduralMountains(Canvas canvas, double w, double groundTop, _Theme theme) {
    void layer(double amp, double seed, Color color, Color? cap) {
      final path = Path()..moveTo(0, groundTop + 2);
      for (double x = 0; x <= w + 20; x += 18) {
        final a = 1 - (math.sin(x * 0.0085 + seed)).abs();
        final b = 1 - (math.sin(x * 0.021 + seed * 2.3)).abs();
        final y = groundTop - amp * (0.25 + 0.55 * a + 0.2 * b);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w + 20, groundTop + 2)
        ..close();
      final rect = Rect.fromLTWH(0, groundTop - amp, w, amp + 2);
      final c = _dim(color);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: cap == null ? [c, c] : [_dim(cap), _dim(cap), c, c],
            stops: cap == null ? const [0, 1] : const [0, 0.2, 0.32, 1],
          ).createShader(rect),
      );
    }

    layer(groundTop * 0.62, 1.3, theme.farMountain, theme.snowCap);
    layer(groundTop * 0.38, 4.1, theme.nearMountain, null);
  }

  // -------------------------------------------------------------------- trees
  void drawTrees(Canvas canvas, double w, double h, double groundTop) {
    final theme = _theme;
    final art = _available(theme.treeKeys);
    final t = game.dayNightClock;
    final baseH = (groundTop * 0.5).clamp(48.0, 150.0);
    final maxDrop = game.pixelsPerUnit * 0.3;
    // Far-to-near so nearer trees overlap farther ones.
    final sorted = [..._trees]..sort((a, b) => a.depth.compareTo(b.depth));
    final paint = _imagePaint();
    for (final p in sorted) {
      final x = p.xFrac * w;
      final baseY = groundTop + 4 + p.depth * maxDrop;
      final height = baseH * (0.8 + 0.4 * p.depth) * p.scale;
      final sway = math.sin(t * 0.9 + p.phase) * 0.018;
      if (art.isNotEmpty) {
        _drawImageAtBase(canvas, art[p.variant % art.length], x, baseY, height, p.flip, sway, paint);
      } else {
        _proceduralTree(canvas, x, baseY, height, sway, theme);
      }
    }
  }

  void _proceduralTree(Canvas canvas, double x, double baseY, double h, double sway, _Theme theme) {
    canvas.save();
    canvas.translate(x, baseY);
    canvas.rotate(sway);
    final trunk = Paint()..color = _dim(theme.trunk);
    final leaf = Paint()..color = _dim(theme.leaf);
    switch (_biome) {
      case _Biome.green:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-h * 0.06, -h * 0.45, h * 0.12, h * 0.45), const Radius.circular(2)),
          trunk,
        );
        for (final o in [Offset(0, -h * 0.72), Offset(-h * 0.2, -h * 0.58), Offset(h * 0.2, -h * 0.58)]) {
          canvas.drawCircle(o, h * 0.26, leaf);
        }
        canvas.drawCircle(Offset(-h * 0.08, -h * 0.74), h * 0.14, Paint()..color = _dim(const Color(0xFF66BB6A)).withValues(alpha: 0.55));
        break;
      case _Biome.snow:
        canvas.drawRect(Rect.fromLTWH(-h * 0.04, -h * 0.12, h * 0.08, h * 0.12), trunk);
        for (var i = 0; i < 3; i++) {
          final top = -h * (0.95 - i * 0.26);
          final bot = -h * (0.45 - i * 0.12) - h * 0.05;
          final half = h * (0.14 + i * 0.07);
          final tri = Path()
            ..moveTo(0, top)
            ..lineTo(-half, bot)
            ..lineTo(half, bot)
            ..close();
          canvas.drawPath(tri, leaf);
          canvas.drawPath(
            Path()
              ..moveTo(0, top)
              ..lineTo(-half * 0.5, top + (bot - top) * 0.45)
              ..lineTo(half * 0.5, top + (bot - top) * 0.45)
              ..close(),
            Paint()..color = _dim(Colors.white),
          );
        }
        break;
      case _Biome.burnt:
      case _Biome.storm:
        final stroke = Paint()
          ..color = _dim(theme.trunk)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(2.0, h * 0.06);
        canvas.drawLine(Offset.zero, Offset(0, -h * 0.7), stroke);
        stroke.strokeWidth = math.max(1.4, h * 0.035);
        canvas.drawLine(Offset(0, -h * 0.4), Offset(-h * 0.22, -h * 0.65), stroke);
        canvas.drawLine(Offset(0, -h * 0.55), Offset(h * 0.2, -h * 0.85), stroke);
        canvas.drawLine(Offset(0, -h * 0.7), Offset(-h * 0.08, -h * 0.95), stroke);
        break;
    }
    canvas.restore();
  }

  // -------------------------------------------------------------------- grass
  void drawGrass(Canvas canvas, double w, double h, double groundTop) {
    final theme = _theme;
    final art = _available(theme.grassKeys);
    final t = game.dayNightClock;
    final span = h - groundTop - 14;
    if (span <= 0) return;
    final paint = _imagePaint();
    for (final p in _tufts) {
      final x = p.xFrac * w;
      final baseY = groundTop + 12 + p.depth * span;
      final height = (13 + 13 * p.depth) * p.scale;
      final sway = math.sin(t * 1.7 + p.phase) * 0.07;
      if (art.isNotEmpty) {
        _drawImageAtBase(canvas, art[p.variant % art.length], x, baseY, height, p.flip, sway, paint);
      } else {
        _proceduralTuft(canvas, x, baseY, height, sway, theme);
      }
    }
  }

  void _proceduralTuft(Canvas canvas, double x, double baseY, double h, double sway, _Theme theme) {
    canvas.save();
    canvas.translate(x, baseY);
    canvas.rotate(sway);
    final blade = Paint()
      ..color = _dim(theme.tuft)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.4, h * 0.11);
    for (var i = -2; i <= 2; i++) {
      final path = Path()
        ..moveTo(i * h * 0.12, 0)
        ..quadraticBezierTo(i * h * 0.2, -h * 0.55, i * h * 0.34, -h * (0.85 - i.abs() * 0.12));
      canvas.drawPath(path, blade);
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------ helpers
  /// Draws [img] standing on (x, baseY) — its bottom-centre is the anchor — at
  /// [height], keeping proportions, leaning by [sway] radians about the base.
  void _drawImageAtBase(
    Canvas canvas,
    ui.Image img,
    double x,
    double baseY,
    double height,
    bool flip,
    double sway,
    Paint paint,
  ) {
    final width = height * img.width / img.height;
    canvas.save();
    canvas.translate(x, baseY);
    canvas.rotate(sway);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-width / 2, -height, width, height),
      paint,
    );
    canvas.restore();
  }
}
