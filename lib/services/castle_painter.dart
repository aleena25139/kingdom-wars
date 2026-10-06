// Procedural (code-drawn) castle art. Used whenever a castle_N_stage_M.png is
// missing from assets/ — so the player's castle ALWAYS has art, and you never
// need to draw 700 images by hand. Your own PNGs still win: if the exact file
// exists it is used, this painter only fills the gaps.
//
// Every castle design is generated from a seed (the absolute design index, so
// designs never repeat even past level 700): palette, tower style, gate shape,
// wall height, roof/spire style and banner shape all come from that seed. The
// 7 stages of one design grow the SAME castle step by step:
//   1 wall + gate + small keep      5 + second pair of towers
//   2 + first pair of side towers   6 + third keep tier
//   3 + second keep tier            7 + gold trim, glow, extra banners
//   4 + banners
// Painted on a transparent canvas in a 100x100 design space, scaled to size.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/castle_art_data.dart';

class _Pal {
  final Color wall, shade, light, roof, accent, gate;
  const _Pal(this.wall, this.shade, this.light, this.roof, this.accent, this.gate);
}

class CastlePainter {
  CastlePainter._();

  static const Color _outline = Color(0xFF2B1B10);
  static const Color _window = Color(0xFFFFE08A);
  static const Color _gold = Color(0xFFFFD700);

  static const List<_Pal> _palettes = [
    // sandstone + brown roof
    _Pal(Color(0xFFD9B77A), Color(0xFFB48F55), Color(0xFFEBD3A0), Color(0xFF8B4A2B), Color(0xFFE63946), Color(0xFF4A2C17)),
    // brown brick + green roof
    _Pal(Color(0xFF9C6B43), Color(0xFF744A2B), Color(0xFFB88659), Color(0xFF3E6B2F), Color(0xFFFFD700), Color(0xFF2E1A0D)),
    // mossy green stone
    _Pal(Color(0xFF7C9A6B), Color(0xFF5A774D), Color(0xFF9DB98B), Color(0xFF6B4423), Color(0xFFFFD700), Color(0xFF2E2415)),
    // grey stone + red roof
    _Pal(Color(0xFFA9AFB5), Color(0xFF7E858C), Color(0xFFC9CED2), Color(0xFFB23A3A), Color(0xFF3A7BD5), Color(0xFF3B2A20)),
    // slate blue
    _Pal(Color(0xFF7A8BA8), Color(0xFF55657F), Color(0xFF9FB0CB), Color(0xFF2D4A8A), Color(0xFFFFD700), Color(0xFF26202E)),
    // white marble + gold roof
    _Pal(Color(0xFFEDE8DC), Color(0xFFC9C1AE), Color(0xFFFFFFFF), Color(0xFFD4A017), Color(0xFF8E2DE2), Color(0xFF4A3A2A)),
    // dark obsidian
    _Pal(Color(0xFF4A4452), Color(0xFF2F2A36), Color(0xFF6A6475), Color(0xFF8B1E1E), Color(0xFFFF7A18), Color(0xFF15111A)),
    // royal purple
    _Pal(Color(0xFF8A6FB0), Color(0xFF65508A), Color(0xFFA991CC), Color(0xFFFFD700), Color(0xFFE63946), Color(0xFF2A1E3A)),
    // terracotta
    _Pal(Color(0xFFC77B58), Color(0xFF9E5A3C), Color(0xFFDE9A78), Color(0xFF2F6F4E), Color(0xFFFFF1A8), Color(0xFF3A2015)),
    // ice (index 9 — also used for the Frozen Pass chapter)
    _Pal(Color(0xFFBFE3F2), Color(0xFF8FC1D9), Color(0xFFE6F6FC), Color(0xFF4A90C2), Color(0xFFFFFFFF), Color(0xFF2A3A4A)),
  ];

  /// Paints the castle for [level] into a [size]-sized box at the canvas
  /// origin. [ice] forces the icy palette (Frozen Pass). [time] (seconds)
  /// only drives the banner wave.
  static void paint(Canvas canvas, Size size, int level, {bool ice = false, double time = 0}) {
    final design = CastleArtData.designIndexForLevel(level);
    final stage = CastleArtData.stageNumberForLevel(level);
    final rnd = math.Random(design * 7919 + 17);

    final pal = ice ? _palettes[9] : _palettes[rnd.nextInt(_palettes.length)];
    final towerStyle = rnd.nextInt(3); // 0 crenellated, 1 cone, 2 dome
    final keepStyle = rnd.nextInt(3); // top of the central keep
    final archGate = rnd.nextBool();
    final roundFlag = rnd.nextBool();
    final wallH = 18.0 + rnd.nextInt(6);
    final towerW = 11.0 + rnd.nextInt(4);

    canvas.save();
    canvas.scale(size.width / 100.0, size.height / 100.0);

    const groundY = 92.0;
    final wallTop = groundY - wallH;
    final gold = stage >= 7;

    // Stage 7 glow behind the castle.
    if (gold) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: const Offset(50, 50), radius: 52));
      canvas.drawCircle(const Offset(50, 50), 52, glow);
    }

    // Curtain wall.
    _box(canvas, Rect.fromLTWH(10, wallTop, 80, wallH), pal.wall);
    _bricks(canvas, Rect.fromLTWH(10, wallTop, 80, wallH), pal.shade);
    _crenels(canvas, 10, wallTop, 80, pal.wall, count: 11);
    if (gold) _trim(canvas, Rect.fromLTWH(10, wallTop + 3, 80, 1.6));

    // Back pair of towers (stage 5+), then front pair (stage 2+).
    if (stage >= 5) {
      final h = wallH + 6 + stage;
      _tower(canvas, 30, groundY, towerW * 0.8, h, towerStyle, pal, gold, time, roundFlag);
      _tower(canvas, 70, groundY, towerW * 0.8, h, towerStyle, pal, gold, time, roundFlag);
    }
    if (stage >= 2) {
      final h = wallH + 10 + stage * 2;
      _tower(canvas, 14, groundY, towerW, h, towerStyle, pal, gold, time, roundFlag);
      _tower(canvas, 86, groundY, towerW, h, towerStyle, pal, gold, time, roundFlag);
    }

    // Central keep: 1 tier at stage 1-2, 2 at stage 3-5, 3 at stage 6+.
    final tiers = 1 + (stage >= 3 ? 1 : 0) + (stage >= 6 ? 1 : 0);
    var tierBottom = groundY;
    var tierW = 30.0;
    for (var i = 0; i < tiers; i++) {
      final tierH = i == 0 ? wallH + 14 : 14.0;
      final r = Rect.fromLTWH(50 - tierW / 2, tierBottom - tierH, tierW, tierH);
      _box(canvas, r, pal.wall);
      canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.72, r.top, r.width * 0.28, r.height),
          Paint()..color = pal.shade);
      _bricks(canvas, r, pal.shade);
      if (gold) _trim(canvas, Rect.fromLTWH(r.left, r.top, r.width, 1.6));
      if (i > 0) _windows(canvas, r, 3);
      tierBottom -= tierH;
      if (i < tiers - 1) tierW -= 6;
    }
    // Keep top.
    final keepTop = tierBottom;
    final topW = tierW;
    if (keepStyle == 0) {
      _crenels(canvas, 50 - topW / 2 - 1, keepTop, topW + 2, pal.wall, count: 5);
      _flag(canvas, 50, keepTop - 3, pal, time, roundFlag, big: true);
    } else if (keepStyle == 1) {
      _cone(canvas, 50, keepTop, topW + 4, topW * 0.9, pal);
      _flag(canvas, 50, keepTop - topW * 0.9, pal, time, roundFlag, big: true);
    } else {
      _dome(canvas, 50, keepTop, topW + 3, pal, gold);
      _flag(canvas, 50, keepTop - (topW + 3) * 0.7, pal, time, roundFlag, big: true);
    }

    // Gate (on the keep's first tier).
    _gate(canvas, 50, groundY, 12, archGate ? 17 : 15, archGate, pal);

    // Small flag on each wall end from stage 4.
    if (stage >= 4) {
      _flag(canvas, 12, wallTop - 3, pal, time + 0.7, roundFlag);
      _flag(canvas, 88, wallTop - 3, pal, time + 1.4, roundFlag);
    }

    // Ground line.
    canvas.drawRect(
        const Rect.fromLTWH(6, groundY, 88, 2.2), Paint()..color = const Color(0xFF3F2A18));

    canvas.restore();
  }

  // ---------- building blocks ----------

  static void _box(Canvas c, Rect r, Color fill) {
    c.drawRect(r, Paint()..color = fill);
    c.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = _outline);
  }

  static void _bricks(Canvas c, Rect r, Color line) {
    final p = Paint()
      ..color = line.withValues(alpha: 0.45)
      ..strokeWidth = 0.4;
    for (var y = r.top + 5; y < r.bottom - 1; y += 5) {
      c.drawLine(Offset(r.left + 0.5, y), Offset(r.right - 0.5, y), p);
    }
  }

  static void _crenels(Canvas c, double x, double y, double w, Color fill, {required int count}) {
    final mw = w / (count * 2 - 1);
    for (var i = 0; i < count; i++) {
      _box(c, Rect.fromLTWH(x + i * mw * 2, y - 3, mw, 3.2), fill);
    }
  }

  static void _trim(Canvas c, Rect r) {
    c.drawRect(r, Paint()..color = _gold);
  }

  static void _windows(Canvas c, Rect r, int n) {
    for (var i = 0; i < n; i++) {
      final cx = r.left + r.width * (i + 1) / (n + 1);
      final w = Rect.fromLTWH(cx - 1.3, r.top + r.height * 0.3, 2.6, 5);
      c.drawRect(w, Paint()..color = _window);
      c.drawRect(
          w,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4
            ..color = _outline);
    }
  }

  static void _tower(Canvas c, double cx, double groundY, double w, double h, int style, _Pal p,
      bool gold, double time, bool roundFlag) {
    final x = cx - w / 2;
    final top = groundY - h;
    final body = Rect.fromLTWH(x, top, w, h);
    _box(c, body, p.wall);
    c.drawRect(Rect.fromLTWH(x + w * 0.68, top, w * 0.32, h), Paint()..color = p.shade);
    c.drawRect(Rect.fromLTWH(x, top, w * 0.12, h), Paint()..color = p.light);
    _bricks(c, body, p.shade);
    _windows(c, Rect.fromLTWH(x, top + 2, w, h * 0.5), 1);
    if (gold) _trim(c, Rect.fromLTWH(x, top + 3, w, 1.4));
    if (style == 0) {
      _crenels(c, x - 1, top, w + 2, p.wall, count: 3);
      _flag(c, cx, top - 3, p, time + cx * 0.05, roundFlag);
    } else if (style == 1) {
      _cone(c, cx, top, w + 4, w * 1.1, p);
      _flag(c, cx, top - w * 1.1, p, time + cx * 0.05, roundFlag);
    } else {
      _dome(c, cx, top, w + 3, p, gold);
      _flag(c, cx, top - (w + 3) * 0.7, p, time + cx * 0.05, roundFlag);
    }
  }

  static void _cone(Canvas c, double cx, double baseY, double w, double h, _Pal p) {
    final path = Path()
      ..moveTo(cx - w / 2, baseY)
      ..lineTo(cx + w / 2, baseY)
      ..lineTo(cx, baseY - h)
      ..close();
    c.drawPath(path, Paint()..color = p.roof);
    final shade = Path()
      ..moveTo(cx, baseY - h)
      ..lineTo(cx + w / 2, baseY)
      ..lineTo(cx, baseY)
      ..close();
    c.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.2));
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = _outline);
  }

  static void _dome(Canvas c, double cx, double baseY, double w, _Pal p, bool gold) {
    final path = Path()
      ..moveTo(cx - w / 2, baseY)
      ..arcTo(Rect.fromLTWH(cx - w / 2, baseY - w * 0.7, w, w * 1.4), math.pi, math.pi, false)
      ..close();
    c.drawPath(path, Paint()..color = gold ? _gold : p.roof);
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = _outline);
    // little highlight
    c.drawCircle(Offset(cx - w * 0.15, baseY - w * 0.32), w * 0.07,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  static void _flag(Canvas c, double x, double y, _Pal p, double time, bool round,
      {bool big = false}) {
    final len = big ? 9.0 : 6.0;
    final pole = Paint()
      ..color = _outline
      ..strokeWidth = 0.7;
    c.drawLine(Offset(x, y), Offset(x, y - len), pole);
    final wave = math.sin(time * 4) * 1.2;
    final fw = big ? 7.0 : 5.0;
    final fh = big ? 4.0 : 3.0;
    final path = Path()..moveTo(x, y - len);
    if (round) {
      path
        ..quadraticBezierTo(x + fw * 0.6, y - len - 1 + wave, x + fw, y - len + fh / 2 + wave)
        ..quadraticBezierTo(x + fw * 0.6, y - len + fh + wave * 0.5, x, y - len + fh);
    } else {
      path
        ..lineTo(x + fw, y - len + fh / 2 + wave)
        ..lineTo(x, y - len + fh);
    }
    path.close();
    c.drawPath(path, Paint()..color = p.accent);
  }

  static void _gate(Canvas c, double cx, double groundY, double w, double h, bool arch, _Pal p) {
    final x = cx - w / 2;
    final path = Path()..moveTo(x, groundY);
    if (arch) {
      path
        ..lineTo(x, groundY - h + w / 2)
        ..arcTo(Rect.fromLTWH(x, groundY - h, w, w), math.pi, math.pi, false)
        ..lineTo(x + w, groundY);
    } else {
      path
        ..lineTo(x, groundY - h)
        ..lineTo(x + w, groundY - h)
        ..lineTo(x + w, groundY);
    }
    path.close();
    c.drawPath(path, Paint()..color = p.gate);
    // portcullis bars
    final bars = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final bx = x + w * i / 4;
      c.drawLine(Offset(bx, groundY - h + 2), Offset(bx, groundY), bars);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = _outline);
  }
}
