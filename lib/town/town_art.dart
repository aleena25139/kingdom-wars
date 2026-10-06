// Draws every Town piece in code (no image assets needed): ground, streets,
// houses, public buildings, parks and decorations. Everything is drawn into
// a single tile Rect `r`; tall things (apartments, towers, windmill) simply
// extend ABOVE the tile, so painting rows top-to-bottom stacks them
// correctly. `t` is a running time in seconds used for little animations
// (fountain jets, smoke, swinging swings, spinning windmill, clock hands).
import 'dart:math' as math;

import 'package:flutter/material.dart';

part 'town_art_extra.dart';

class TownArt {
  TownArt._();

  // Road connection bits.
  static const int north = 1, east = 2, south = 4, west = 8;

  static bool isRoadId(String? id) => id == 'road' || id == 'cobble' || id == 'plaza';

  static bool isFieldId(String? id) => id == 'wheat_field' || id == 'veg_field' || id == 'pasture';

  /// Flat water that joins up with its neighbours (river). 'lake' is a single blob.
  static bool isWaterId(String? id) => id == 'river' || id == 'lake';

  /// Pieces a river runs under / through (bridges and boats sit on water).
  static bool isOnWaterId(String? id) => id == 'bridge' || id == 'stone_bridge' || id == 'boat';

  /// Water connection for auto-joining rivers: river, lake and everything on water.
  static bool connectsWater(String? id) => isWaterId(id) || isOnWaterId(id);

  /// Rails join up with each other, with trains on them and with stations.
  static bool isRailId(String? id) => id == 'rail' || id == 'train' || id == 'train_wagon';
  static bool connectsRail(String? id) => isRailId(id) || id == 'station' || id == 'train_stop';

  /// Bridges let a street run across the water.
  static bool connectsRoad(String? id) => isRoadId(id) || id == 'bridge' || id == 'stone_bridge';

  /// Flat tiles drawn in the ground layer (below buildings).
  static bool isFlatId(String? id) =>
      isRoadId(id) || isFieldId(id) || isWaterId(id) || isRailId(id) || isOnWaterId(id) || id == 'lego_plate';

  // ------------------------------------------------------------------
  // Small helpers
  // ------------------------------------------------------------------
  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static int _hash(int a, int b) {
    var h = a * 73856093 ^ b * 19349663;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  static void _groundShadow(Canvas c, Rect r, {double wf = 0.82}) {
    final s = r.width;
    c.drawOval(
      Rect.fromCenter(center: Offset(r.center.dx, r.bottom - s * 0.1), width: s * wf, height: s * 0.2),
      _fill(Colors.black.withValues(alpha: 0.2)),
    );
  }

  /// A wall with a darker right side for a bit of depth.
  static void _wall(Canvas c, Rect box, Color color, {double radius = 2}) {
    final rr = RRect.fromRectAndRadius(box, Radius.circular(radius));
    c.drawRRect(rr, _fill(color));
    c.drawRect(Rect.fromLTRB(box.right - box.width * 0.2, box.top, box.right, box.bottom),
        _fill(Colors.black.withValues(alpha: 0.12)));
    c.drawRRect(rr, _stroke(_shade(color, -0.3), math.max(1, box.width * 0.025)));
  }

  static void _gable(Canvas c, Rect box, Color color, double rise, {double overhang = 0.06}) {
    final ov = box.width * overhang;
    final p = Path()
      ..moveTo(box.left - ov, box.top + 1)
      ..lineTo(box.center.dx, box.top - rise)
      ..lineTo(box.right + ov, box.top + 1)
      ..close();
    c.drawPath(p, _fill(color));
    final dark = Path()
      ..moveTo(box.center.dx, box.top - rise)
      ..lineTo(box.right + ov, box.top + 1)
      ..lineTo(box.center.dx, box.top + 1)
      ..close();
    c.drawPath(dark, _fill(Colors.black.withValues(alpha: 0.16)));
    c.drawPath(p, _stroke(_shade(color, -0.3), math.max(1, box.width * 0.025)));
  }

  static void _window(Canvas c, Rect w, {Color glass = const Color(0xFF9AD7F5), bool lit = false}) {
    c.drawRect(w, _fill(lit ? const Color(0xFFFFE08A) : glass));
    c.drawRect(w, _stroke(const Color(0xFF4A3220), math.max(0.8, w.width * 0.12)));
    c.drawLine(Offset(w.center.dx, w.top), Offset(w.center.dx, w.bottom), _stroke(const Color(0xFF4A3220), 0.7));
  }

  static void _windowGrid(Canvas c, Rect area, int rows, int cols, {bool litAlt = false, Color glass = const Color(0xFF9AD7F5)}) {
    final cw = area.width / cols;
    final ch = area.height / rows;
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        final w = Rect.fromLTWH(area.left + j * cw + cw * 0.2, area.top + i * ch + ch * 0.18, cw * 0.6, ch * 0.64);
        _window(c, w, glass: glass, lit: litAlt && (i + j) % 3 == 0);
      }
    }
  }

  static void _door(Canvas c, Rect d, {Color color = const Color(0xFF6B4423)}) {
    c.drawRRect(
      RRect.fromRectAndCorners(d, topLeft: Radius.circular(d.width * 0.5), topRight: Radius.circular(d.width * 0.5)),
      _fill(color),
    );
    c.drawCircle(Offset(d.right - d.width * 0.22, d.center.dy + d.height * 0.1), math.max(0.8, d.width * 0.07),
        _fill(const Color(0xFFF2CE7C)));
  }

  static void _smoke(Canvas c, Offset base, double t, double s) {
    for (var i = 0; i < 3; i++) {
      final k = ((t * 0.45) + i / 3) % 1.0;
      final pos = base.translate(math.sin(k * 5 + i) * s * 0.04 + k * s * 0.1, -k * s * 0.42);
      c.drawCircle(pos, s * (0.03 + 0.05 * k), _fill(Colors.white.withValues(alpha: 0.55 * (1 - k))));
    }
  }

  static void _flag(Canvas c, Offset pole, double height, double t, Color color) {
    c.drawLine(pole, pole.translate(0, -height), _stroke(const Color(0xFF3B2A1A), 1.4));
    final w = height * 0.55;
    final wave = math.sin(t * 5) * height * 0.06;
    final p = Path()
      ..moveTo(pole.dx, pole.dy - height)
      ..quadraticBezierTo(pole.dx + w * 0.5, pole.dy - height + wave, pole.dx + w, pole.dy - height * 0.9)
      ..quadraticBezierTo(pole.dx + w * 0.5, pole.dy - height * 0.7 - wave, pole.dx, pole.dy - height * 0.65)
      ..close();
    c.drawPath(p, _fill(color));
  }

  static void _columns(Canvas c, Rect area, int n, Color color) {
    final cw = area.width / n;
    for (var i = 0; i < n; i++) {
      final x = area.left + cw * (i + 0.5);
      final col = Rect.fromCenter(center: Offset(x, area.center.dy), width: cw * 0.38, height: area.height);
      c.drawRect(col, _fill(color));
      c.drawRect(col, _stroke(_shade(color, -0.25), 0.8));
    }
  }

  static void _stripedAwning(Canvas c, Rect a, Color c1, Color c2, int stripes) {
    final sw = a.width / stripes;
    for (var i = 0; i < stripes; i++) {
      final p = Path()
        ..moveTo(a.left + i * sw, a.top)
        ..lineTo(a.left + (i + 1) * sw, a.top)
        ..lineTo(a.left + (i + 1) * sw, a.bottom - 2)
        ..quadraticBezierTo(a.left + (i + 0.5) * sw, a.bottom + 3, a.left + i * sw, a.bottom - 2)
        ..close();
      c.drawPath(p, _fill(i.isEven ? c1 : c2));
    }
    c.drawLine(Offset(a.left, a.top), Offset(a.right, a.top), _stroke(Colors.black.withValues(alpha: 0.35), 1));
  }

  // ------------------------------------------------------------------
  // Medieval building helpers
  // ------------------------------------------------------------------
  /// Stone wall with a block pattern.
  static void _stoneBlocks(Canvas c, Rect box, Color base) {
    final s = box.width;
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(2));
    c.drawRRect(rr, _fill(base));
    final line = _stroke(_shade(base, -0.18).withValues(alpha: 0.75), 0.8);
    final bh = s * 0.11;
    var i = 0;
    for (var y = box.top + bh; y < box.bottom - 1; y += bh, i++) {
      c.drawLine(Offset(box.left, y), Offset(box.right, y), line);
      final off = i.isEven ? 0.0 : bh * 0.9;
      for (var x = box.left + off + bh * 1.6; x < box.right; x += bh * 1.8) {
        c.drawLine(Offset(x, y - bh), Offset(x, y), line);
      }
    }
    c.drawRect(Rect.fromLTRB(box.right - s * 0.2, box.top, box.right, box.bottom), _fill(Colors.black.withValues(alpha: 0.14)));
    c.drawRRect(rr, _stroke(_shade(base, -0.32), math.max(1, s * 0.025)));
  }

  /// Plaster wall with dark timber beams and diagonal braces.
  static void _timberWall(Canvas c, Rect box, Color plaster, {int bays = 2, bool braces = true}) {
    const beam = Color(0xFF4A3220);
    final s = box.width;
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(1.5)), _fill(plaster));
    c.drawRect(Rect.fromLTRB(box.right - s * 0.18, box.top, box.right, box.bottom), _fill(Colors.black.withValues(alpha: 0.1)));
    final bw = math.max(1.2, s * 0.04);
    final bp = _stroke(beam, bw);
    for (var i = 0; i <= bays; i++) {
      final x = box.left + box.width * i / bays;
      c.drawLine(Offset(x, box.top), Offset(x, box.bottom), bp);
    }
    if (braces) {
      final bayW = box.width / bays;
      final dp = _stroke(beam, bw * 0.7);
      for (var i = 0; i < bays; i++) {
        final x0 = box.left + bayW * i;
        if (i.isEven) {
          c.drawLine(Offset(x0, box.bottom), Offset(x0 + bayW, box.top), dp);
        } else {
          c.drawLine(Offset(x0, box.top), Offset(x0 + bayW, box.bottom), dp);
        }
      }
    }
    c.drawRect(box, bp);
  }

  /// Gable roof covered in rows of tiles / shingles / slate.
  static void _tiledRoof(Canvas c, Rect box, Color color, double rise, {double overhang = 0.07}) {
    _gable(c, box, color, rise, overhang: overhang);
    final ov = box.width * overhang;
    c.save();
    c.clipPath(Path()
      ..moveTo(box.left - ov, box.top + 1)
      ..lineTo(box.center.dx, box.top - rise)
      ..lineTo(box.right + ov, box.top + 1)
      ..close());
    final line = _stroke(_shade(color, -0.2).withValues(alpha: 0.8), 0.8);
    final step = rise / 4;
    for (var y = box.top - rise + step; y < box.top + 1; y += step) {
      c.drawLine(Offset(box.left - ov, y), Offset(box.right + ov, y), line);
    }
    c.restore();
  }

  /// Straw roof: dense vertical strands and a ragged fringe along the eaves.
  static void _thatch(Canvas c, Rect box, double rise, Color color, {double overhang = 0.14}) {
    final ov = box.width * overhang;
    final halfW = box.width / 2 + ov;
    final cx = box.center.dx;
    final path = Path()
      ..moveTo(box.left - ov, box.top + 2)
      ..lineTo(cx, box.top - rise)
      ..lineTo(box.right + ov, box.top + 2)
      ..close();
    c.drawPath(path, _fill(color));
    c.save();
    c.clipPath(path);
    final strand = _stroke(_shade(color, -0.14).withValues(alpha: 0.8), 0.9);
    for (var x = box.left - ov; x <= box.right + ov; x += box.width * 0.075) {
      final top = box.top - rise * (1 - (x - cx).abs() / halfW);
      c.drawLine(Offset(x, top), Offset(x, box.top + 2), strand);
    }
    c.drawPath(
      Path()
        ..moveTo(cx, box.top - rise)
        ..lineTo(box.right + ov, box.top + 2)
        ..lineTo(cx, box.top + 2)
        ..close(),
      _fill(Colors.black.withValues(alpha: 0.14)),
    );
    c.restore();
    // ragged fringe
    final fringe = _fill(_shade(color, -0.05));
    for (var x = box.left - ov + 2; x < box.right + ov; x += box.width * 0.11) {
      c.drawOval(Rect.fromCenter(center: Offset(x, box.top + 2), width: box.width * 0.1, height: box.width * 0.07), fringe);
    }
    c.drawPath(path, _stroke(_shade(color, -0.3), math.max(1, box.width * 0.02)));
  }

  /// Window with wooden shutters.
  static void _shutterWindow(Canvas c, Rect w, {bool lit = false}) {
    _window(c, w, lit: lit);
    final sw = w.width * 0.42;
    final shutter = _fill(const Color(0xFF6B4423));
    c.drawRect(Rect.fromLTWH(w.left - sw, w.top, sw, w.height), shutter);
    c.drawRect(Rect.fromLTWH(w.right, w.top, sw, w.height), shutter);
  }

  static void _stoneChimney(Canvas c, Rect ch) {
    c.drawRect(ch, _fill(const Color(0xFF8A857C)));
    c.drawRect(ch, _stroke(const Color(0xFF5E5A53), 0.9));
    c.drawRect(Rect.fromLTWH(ch.left - ch.width * 0.15, ch.top - ch.width * 0.25, ch.width * 1.3, ch.width * 0.3),
        _fill(const Color(0xFF6E6A63)));
  }

  // ------------------------------------------------------------------
  // Ground
  // ------------------------------------------------------------------
  static void drawGround(Canvas c, Rect r, int col, int row, {bool detail = true}) {
    final alt = (col + row) % 2 == 0;
    c.drawRect(r, _fill(alt ? const Color(0xFF74C255) : const Color(0xFF6DBB4E)));
    if (!detail) return;
    final h = _hash(col, row);
    final s = r.width;
    final tuft = _stroke(const Color(0xFF4F9A3A), math.max(1, s * 0.03));
    for (var i = 0; i < 3; i++) {
      final hx = _hash(h, i + 1);
      final x = r.left + (hx % 100) / 100 * s * 0.84 + s * 0.08;
      final y = r.top + ((hx ~/ 100) % 100) / 100 * s * 0.84 + s * 0.12;
      c.drawLine(Offset(x, y), Offset(x - s * 0.03, y - s * 0.07), tuft);
      c.drawLine(Offset(x, y), Offset(x + s * 0.03, y - s * 0.07), tuft);
    }
    if (h % 7 == 0) {
      final x = r.left + (h % 53) / 53 * s * 0.8 + s * 0.1;
      final y = r.top + (h % 47) / 47 * s * 0.8 + s * 0.1;
      c.drawCircle(Offset(x, y), s * 0.025, _fill(h % 2 == 0 ? Colors.white : const Color(0xFFFFD54F)));
    }
  }

  // ------------------------------------------------------------------
  // Streets (drawn on the ground layer, below buildings)
  // ------------------------------------------------------------------
  static void drawRoad(Canvas c, String id, Rect r, int mask, int col, int row) {
    final s = r.width;
    if (id == 'plaza') {
      c.drawRect(r.deflate(s * 0.02), _fill(const Color(0xFFE2D3B3)));
      c.drawRect(r.deflate(s * 0.02), _stroke(const Color(0xFFA68F66), s * 0.03));
      final line = _stroke(const Color(0xFFBFA77B), 1);
      for (var i = 1; i < 4; i++) {
        c.drawLine(Offset(r.left + s * i / 4, r.top + s * 0.04), Offset(r.left + s * i / 4, r.bottom - s * 0.04), line);
        c.drawLine(Offset(r.left + s * 0.04, r.top + s * i / 4), Offset(r.right - s * 0.04, r.top + s * i / 4), line);
      }
      return;
    }
    final cobble = id == 'cobble';
    final base = cobble ? const Color(0xFF9C9C9C) : const Color(0xFFB98F5B);
    final edge = cobble ? const Color(0xFF6D6D6D) : const Color(0xFF8A6438);
    final w = s * 0.64;
    final cx = r.center.dx, cy = r.center.dy;

    Rect arm(int bit) {
      switch (bit) {
        case north:
          return Rect.fromLTRB(cx - w / 2, r.top, cx + w / 2, cy);
        case south:
          return Rect.fromLTRB(cx - w / 2, cy, cx + w / 2, r.bottom);
        case east:
          return Rect.fromLTRB(cx, cy - w / 2, r.right, cy + w / 2);
        default:
          return Rect.fromLTRB(r.left, cy - w / 2, cx, cy + w / 2);
      }
    }

    final parts = <Rect>[Rect.fromCenter(center: r.center, width: w, height: w)];
    var m = mask;
    // A lone piece looks like a short horizontal street.
    if (m == 0) m = east | west;
    for (final b in [north, east, south, west]) {
      if (m & b != 0) parts.add(arm(b));
    }
    // Edge (slightly bigger) then surface.
    for (final p in parts) {
      c.drawRect(p.inflate(s * 0.03), _fill(edge));
    }
    for (final p in parts) {
      c.drawRect(p, _fill(base));
    }
    final h = _hash(col, row);
    if (cobble) {
      final line = _stroke(edge.withValues(alpha: 0.6), 0.8);
      for (final p in parts) {
        for (var y = p.top + s * 0.1; y < p.bottom; y += s * 0.14) {
          c.drawLine(Offset(p.left, y), Offset(p.right, y), line);
        }
      }
    } else {
      // pebbles
      for (var i = 0; i < 4; i++) {
        final k = _hash(h, i + 9);
        c.drawCircle(
          Offset(r.left + (k % 100) / 100 * s * 0.6 + s * 0.2, r.top + ((k ~/ 100) % 100) / 100 * s * 0.6 + s * 0.2),
          s * 0.018,
          _fill(const Color(0xFF8A6438).withValues(alpha: 0.6)),
        );
      }
    }
    // dashed centre line along straight runs
    final dash = _stroke(Colors.white.withValues(alpha: cobble ? 0.5 : 0.35), math.max(1, s * 0.025));
    final horiz = m & (east | west) != 0;
    final vert = m & (north | south) != 0;
    if (horiz && !vert) {
      for (var x = r.left + s * 0.08; x < r.right; x += s * 0.24) {
        c.drawLine(Offset(x, cy), Offset(x + s * 0.12, cy), dash);
      }
    } else if (vert && !horiz) {
      for (var y = r.top + s * 0.08; y < r.bottom; y += s * 0.24) {
        c.drawLine(Offset(cx, y), Offset(cx, y + s * 0.12), dash);
      }
    }
  }

  // ------------------------------------------------------------------
  // Fields (flat, drawn in the ground layer). `mask` = which sides have a
  // neighbour of the same kind; those sides get no fence, so painted tiles
  // merge into one big farm.
  // ------------------------------------------------------------------
  static void drawField(Canvas c, String id, Rect r, int mask, double t, int col, int row) {
    final s = r.width;
    final h = _hash(col, row);
    switch (id) {
      case 'wheat_field':
        c.drawRect(r, _fill(const Color(0xFFC8A24A)));
        final furrow = _stroke(const Color(0xFFA9843A), math.max(1, s * 0.03));
        for (var i = 1; i < 5; i++) {
          final x = r.left + s * i / 5;
          c.drawLine(Offset(x, r.top), Offset(x, r.bottom), furrow);
        }
        final stalk = _stroke(const Color(0xFFE9C95A), math.max(1, s * 0.035));
        final head = _fill(const Color(0xFFF4DB7A));
        for (var i = 0; i < 5; i++) {
          for (var j = 0; j < 3; j++) {
            final x = r.left + s * (i + 0.5) / 5;
            final y = r.top + s * (j + 0.85) / 3;
            final sway = math.sin(t * 1.7 + col * 0.9 + row * 0.6 + i * 0.8 + j * 0.5) * s * 0.025;
            c.drawLine(Offset(x, y), Offset(x + sway, y - s * 0.16), stalk);
            c.drawOval(Rect.fromCenter(center: Offset(x + sway, y - s * 0.19), width: s * 0.07, height: s * 0.1), head);
          }
        }
        break;
      case 'veg_field':
        c.drawRect(r, _fill(const Color(0xFF7B5232)));
        final ridge = _fill(const Color(0xFF63401F));
        for (var j = 0; j < 4; j++) {
          c.drawRect(Rect.fromLTWH(r.left, r.top + s * (j * 0.25 + 0.14), s, s * 0.08), ridge);
        }
        final leaf = _fill(const Color(0xFF4C9A3A));
        for (var j = 0; j < 4; j++) {
          for (var i = 0; i < 4; i++) {
            final p = Offset(r.left + s * (i + 0.5) / 4, r.top + s * (j * 0.25 + 0.18));
            c.drawCircle(p, s * 0.06, leaf);
            final k = (i + j + h) % 3;
            if (k == 0) c.drawCircle(p, s * 0.025, _fill(const Color(0xFFE8892B)));
            if (k == 1) c.drawCircle(p, s * 0.025, _fill(const Color(0xFF8E5BA8)));
          }
        }
        break;
      default: // pasture
        c.drawRect(r, _fill(const Color(0xFF86C85A)));
        final tuft = _stroke(const Color(0xFF5FA640), math.max(1, s * 0.03));
        for (var i = 0; i < 5; i++) {
          final hx = _hash(h, i + 3);
          final x = r.left + (hx % 100) / 100 * s * 0.84 + s * 0.08;
          final y = r.top + ((hx ~/ 100) % 100) / 100 * s * 0.8 + s * 0.14;
          c.drawLine(Offset(x, y), Offset(x - s * 0.03, y - s * 0.07), tuft);
          c.drawLine(Offset(x, y), Offset(x + s * 0.03, y - s * 0.07), tuft);
        }
        if (h % 3 == 0) {
          final left = (h ~/ 3) % 2 == 0;
          final bob = math.sin(t * 2 + h) * s * 0.01;
          final ctr = Offset(r.center.dx + ((h % 17) - 8) / 8 * s * 0.12, r.center.dy + ((h % 13) - 6) / 6 * s * 0.1 + bob);
          c.drawLine(ctr.translate(-s * 0.06, s * 0.07), ctr.translate(-s * 0.06, s * 0.12), _stroke(const Color(0xFF3B2A1A), 1.2));
          c.drawLine(ctr.translate(s * 0.06, s * 0.07), ctr.translate(s * 0.06, s * 0.12), _stroke(const Color(0xFF3B2A1A), 1.2));
          c.drawOval(Rect.fromCenter(center: ctr, width: s * 0.26, height: s * 0.17), _fill(const Color(0xFFF7F5EE)));
          c.drawOval(Rect.fromCenter(center: ctr, width: s * 0.26, height: s * 0.17), _stroke(const Color(0xFFCFCBBE), 0.8));
          c.drawOval(
            Rect.fromCenter(center: ctr.translate(left ? -s * 0.14 : s * 0.14, -s * 0.01), width: s * 0.1, height: s * 0.09),
            _fill(const Color(0xFF3F3A36)),
          );
        }
        break;
    }
    // fences along every open edge
    if (mask & north == 0) _fence(c, r, north);
    if (mask & south == 0) _fence(c, r, south);
    if (mask & west == 0) _fence(c, r, west);
    if (mask & east == 0) _fence(c, r, east);
  }

  static void _fence(Canvas c, Rect r, int side) {
    final s = r.width;
    final rail = _stroke(const Color(0xFF7A5230), math.max(1.2, s * 0.035));
    final post = _fill(const Color(0xFF4A3220));
    final pw = math.max(2.0, s * 0.06);
    final horizontal = side == north || side == south;
    if (horizontal) {
      final y = side == north ? r.top + s * 0.04 : r.bottom - s * 0.04;
      c.drawLine(Offset(r.left, y), Offset(r.right, y), rail);
      for (var k = 0; k <= 2; k++) {
        c.drawRect(Rect.fromCenter(center: Offset(r.left + s * k / 2, y), width: pw, height: s * 0.14), post);
      }
    } else {
      final x = side == west ? r.left + s * 0.04 : r.right - s * 0.04;
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), rail);
      for (var k = 0; k <= 2; k++) {
        c.drawRect(Rect.fromCenter(center: Offset(x, r.top + s * k / 2), width: pw, height: s * 0.14), post);
      }
    }
  }

  // ------------------------------------------------------------------
  // Master switch: draw one piece (not roads) into tile rect r.
  // ------------------------------------------------------------------
  static void draw(Canvas c, String id, Rect r, double t, {int col = 0, int row = 0, int roadMask = 0}) {
    if (isRoadId(id)) {
      drawRoad(c, id, r, roadMask, col, row);
      return;
    }
    if (isFieldId(id)) {
      drawField(c, id, r, roadMask, t, col, row);
      return;
    }
    switch (id) {
      case 'hut':
        return _hut(c, r, t);
      case 'cottage':
        return _cottage(c, r, t);
      case 'brick_house':
        return _brickHouse(c, r, t);
      case 'villa':
        return _villa(c, r, t);
      case 'apartment':
        return _apartment(c, r, t);
      case 'bakery':
        return _bakery(c, r, t);
      case 'market':
        return _market(c, r, t, col + row);
      case 'inn':
        return _inn(c, r, t);
      case 'blacksmith':
        return _blacksmith(c, r, t);
      case 'school':
        return _school(c, r, t);
      case 'clinic':
        return _clinic(c, r, t);
      case 'fire_station':
        return _fireStation(c, r, t);
      case 'library':
        return _library(c, r, t);
      case 'clock_tower':
        return _clockTower(c, r, t);
      case 'town_hall':
        return _townHall(c, r, t);
      case 'garden':
        return _garden(c, r, t, col, row);
      case 'fountain_small':
        return _fountain(c, r, t, grand: false);
      case 'fountain_grand':
        return _fountain(c, r, t, grand: true);
      case 'playground':
        return _playground(c, r, t);
      case 'pond':
        return _pond(c, r, t);
      case 'football':
        return _football(c, r, t);
      case 'tree':
        return _tree(c, r, t, col + row);
      case 'pine':
        return _pine(c, r, t);
      case 'flowers':
        return _flowers(c, r, t, col, row);
      case 'bench':
        return _bench(c, r);
      case 'lamp':
        return _lamp(c, r, t);
      case 'well':
        return _well(c, r);
      case 'statue':
        return _statue(c, r);
      case 'windmill':
        return _windmill(c, r, t);
      default:
        // New pieces (water, trains, lego, extra houses/buildings/parks...) live in
        // town_art_extra.dart.
        return TownArtX.draw(c, id, r, t, col: col, row: row, mask: roadMask);
    }
  }

  // ------------------------------------------------------------------
  // Houses
  // ------------------------------------------------------------------
  static void _hut(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.72);
    final box = Rect.fromLTWH(r.left + s * 0.2, r.bottom - s * 0.42, s * 0.6, s * 0.3);
    // wattle & daub wall
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)), _fill(const Color(0xFFB89868)));
    final stake = _stroke(const Color(0xFF8A6A3E), 0.9);
    for (var x = box.left + s * 0.06; x < box.right; x += s * 0.09) {
      c.drawLine(Offset(x, box.top), Offset(x, box.bottom), stake);
    }
    c.drawRect(Rect.fromLTRB(box.right - s * 0.12, box.top, box.right, box.bottom), _fill(Colors.black.withValues(alpha: 0.13)));
    c.drawRect(box, _stroke(const Color(0xFF6B4A28), 1.2));
    _thatch(c, box, s * 0.36, const Color(0xFFD9B04C));
    _smoke(c, Offset(box.center.dx + s * 0.1, box.top - s * 0.28), t, s);
    _door(c, Rect.fromLTWH(box.left + s * 0.08, box.bottom - s * 0.2, s * 0.13, s * 0.2));
    _window(c, Rect.fromLTWH(box.right - s * 0.2, box.top + s * 0.09, s * 0.1, s * 0.1));
    // firewood pile
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(box.right - s * 0.04 + i * s * 0.035, box.bottom - s * 0.025), s * 0.022, _fill(const Color(0xFF7A5230)));
    }
  }

  static void _cottage(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.12, r.bottom - s * 0.54, s * 0.76, s * 0.42);
    final chim = Rect.fromLTWH(box.right - s * 0.22, box.top - s * 0.4, s * 0.1, s * 0.3);
    _stoneChimney(c, chim);
    _timberWall(c, box, const Color(0xFFEFE2C0), bays: 3);
    _tiledRoof(c, box, const Color(0xFF8B5A3C), s * 0.3);
    _smoke(c, chim.topCenter, t, s);
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.24, s * 0.14, s * 0.24));
    _shutterWindow(c, Rect.fromLTWH(box.left + s * 0.14, box.top + s * 0.1, s * 0.1, s * 0.13));
    _shutterWindow(c, Rect.fromLTWH(box.right - s * 0.26, box.top + s * 0.1, s * 0.1, s * 0.13));
    // lantern by the door
    c.drawCircle(Offset(box.center.dx + s * 0.13, box.bottom - s * 0.2), s * 0.018,
        _fill(math.sin(t * 3) > -0.4 ? const Color(0xFFFFD54F) : const Color(0xFFE0A93B)));
  }

  static void _brickHouse(Canvas c, Rect r, double t) {
    // "Stone House"
    final s = r.width;
    _groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.66, s * 0.8, s * 0.54);
    final chim = Rect.fromLTWH(box.left + s * 0.14, box.top - s * 0.42, s * 0.11, s * 0.3);
    _stoneChimney(c, chim);
    _stoneBlocks(c, box, const Color(0xFFA7A39B));
    _tiledRoof(c, box, const Color(0xFF4F5B6B), s * 0.3);
    _smoke(c, chim.topCenter.translate(0, -s * 0.05), t, s);
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.27, s * 0.16, s * 0.27), color: const Color(0xFF5B3A1E));
    _shutterWindow(c, Rect.fromLTWH(box.left + s * 0.14, box.top + s * 0.14, s * 0.11, s * 0.15));
    _shutterWindow(c, Rect.fromLTWH(box.right - s * 0.25, box.top + s * 0.14, s * 0.11, s * 0.15));
    // ivy on the corner
    final ivy = _fill(const Color(0xFF3F7D3A));
    c.drawCircle(Offset(box.left + s * 0.03, box.bottom - s * 0.08), s * 0.05, ivy);
    c.drawCircle(Offset(box.left + s * 0.06, box.bottom - s * 0.17), s * 0.04, ivy);
    c.drawCircle(Offset(box.left + s * 0.03, box.bottom - s * 0.25), s * 0.035, ivy);
  }

  static void _villa(Canvas c, Rect r, double t) {
    // "Manor House": stone ground floor, timber jetty above, round turret.
    final s = r.width;
    _groundShadow(c, r, wf: 0.96);
    final b = r.bottom - s * 0.12;
    final lower = Rect.fromLTRB(r.left + s * 0.06, b - s * 0.28, r.left + s * 0.8, b);
    final upper = Rect.fromLTRB(r.left + s * 0.03, lower.top - s * 0.28, r.left + s * 0.83, lower.top);
    _stoneBlocks(c, lower, const Color(0xFFB2ADA2));
    _timberWall(c, upper, const Color(0xFFF2E8CF), bays: 4);
    _tiledRoof(c, upper, const Color(0xFF8E3B2E), s * 0.3, overhang: 0.05);
    // windows
    _shutterWindow(c, Rect.fromLTWH(upper.left + s * 0.12, upper.top + s * 0.06, s * 0.1, s * 0.15), lit: true);
    _shutterWindow(c, Rect.fromLTWH(upper.center.dx - s * 0.05, upper.top + s * 0.06, s * 0.1, s * 0.15), lit: true);
    _shutterWindow(c, Rect.fromLTWH(upper.right - s * 0.22, upper.top + s * 0.06, s * 0.1, s * 0.15), lit: true);
    _door(c, Rect.fromLTWH(lower.center.dx - s * 0.09, lower.bottom - s * 0.23, s * 0.18, s * 0.23), color: const Color(0xFF3E2A1A));
    _window(c, Rect.fromLTWH(lower.left + s * 0.1, lower.top + s * 0.07, s * 0.08, s * 0.1));
    _window(c, Rect.fromLTWH(lower.right - s * 0.18, lower.top + s * 0.07, s * 0.08, s * 0.1));
    // turret
    final tower = Rect.fromLTRB(r.left + s * 0.72, b - s * 0.8, r.left + s * 0.94, b);
    _stoneBlocks(c, tower, const Color(0xFF9E998E));
    final cone = Path()
      ..moveTo(tower.left - s * 0.03, tower.top + 1)
      ..lineTo(tower.center.dx, tower.top - s * 0.24)
      ..lineTo(tower.right + s * 0.03, tower.top + 1)
      ..close();
    c.drawPath(cone, _fill(const Color(0xFF2F5D8A)));
    c.drawPath(
      Path()
        ..moveTo(tower.center.dx, tower.top - s * 0.24)
        ..lineTo(tower.right + s * 0.03, tower.top + 1)
        ..lineTo(tower.center.dx, tower.top + 1)
        ..close(),
      _fill(Colors.black.withValues(alpha: 0.18)),
    );
    c.drawPath(cone, _stroke(const Color(0xFF1E3E5E), 1));
    c.drawRect(Rect.fromCenter(center: Offset(tower.center.dx, tower.top + s * 0.14), width: s * 0.035, height: s * 0.11),
        _fill(const Color(0xFF1E1B18)));
    c.drawRect(Rect.fromCenter(center: Offset(tower.center.dx, tower.top + s * 0.4), width: s * 0.035, height: s * 0.11),
        _fill(const Color(0xFF1E1B18)));
    _flag(c, Offset(tower.center.dx, tower.top - s * 0.24), s * 0.24, t, const Color(0xFFC0392B));
    // hedges
    c.drawOval(Rect.fromLTWH(lower.left - s * 0.03, lower.bottom - s * 0.07, s * 0.18, s * 0.11), _fill(const Color(0xFF2E7D32)));
    c.drawOval(Rect.fromLTWH(lower.right - s * 0.17, lower.bottom - s * 0.07, s * 0.18, s * 0.11), _fill(const Color(0xFF2E7D32)));
  }

  static void _apartment(Canvas c, Rect r, double t) {
    // "Tall Tenement": three storeys, each one jutting out over the one below.
    final s = r.width;
    _groundShadow(c, r, wf: 0.92);
    final b = r.bottom - s * 0.1;
    final f1 = Rect.fromLTRB(r.left + s * 0.12, b - s * 0.34, r.right - s * 0.12, b);
    final f2 = Rect.fromLTRB(r.left + s * 0.09, f1.top - s * 0.34, r.right - s * 0.09, f1.top);
    final f3 = Rect.fromLTRB(r.left + s * 0.06, f2.top - s * 0.34, r.right - s * 0.06, f2.top);
    final chim = Rect.fromLTWH(f3.left + s * 0.12, f3.top - s * 0.62, s * 0.1, s * 0.32);
    _stoneChimney(c, chim);
    _stoneBlocks(c, f1, const Color(0xFFB0A894));
    _timberWall(c, f2, const Color(0xFFEBDDB8), bays: 3);
    _timberWall(c, f3, const Color(0xFFE4D3A8), bays: 3);
    // jetty shadows under the overhanging floors
    c.drawRect(Rect.fromLTWH(f2.left, f2.bottom, f2.width, s * 0.025), _fill(Colors.black.withValues(alpha: 0.25)));
    c.drawRect(Rect.fromLTWH(f3.left, f3.bottom, f3.width, s * 0.025), _fill(Colors.black.withValues(alpha: 0.25)));
    _tiledRoof(c, f3, const Color(0xFF8E3B2E), s * 0.3, overhang: 0.04);
    _smoke(c, chim.topCenter.translate(0, -s * 0.04), t, s);
    // attic window
    c.drawCircle(Offset(f3.center.dx, f3.top - s * 0.11), s * 0.045, _fill(const Color(0xFFFFE08A)));
    c.drawCircle(Offset(f3.center.dx, f3.top - s * 0.11), s * 0.045, _stroke(const Color(0xFF4A3220), 1));
    // windows
    for (var i = 0; i < 3; i++) {
      final cx = f2.left + f2.width * (i + 0.5) / 3;
      _shutterWindow(c, Rect.fromCenter(center: Offset(cx, f2.center.dy), width: s * 0.09, height: s * 0.14), lit: i == 1);
      _shutterWindow(c, Rect.fromCenter(center: Offset(cx, f3.center.dy), width: s * 0.09, height: s * 0.14), lit: i != 1);
    }
    _door(c, Rect.fromLTWH(f1.center.dx - s * 0.08, f1.bottom - s * 0.22, s * 0.16, s * 0.22), color: const Color(0xFF37281A));
    _window(c, Rect.fromLTWH(f1.left + s * 0.07, f1.top + s * 0.1, s * 0.08, s * 0.1));
    // hanging shop sign
    final sx = f1.right;
    c.drawLine(Offset(sx, f1.top + s * 0.06), Offset(sx + s * 0.1, f1.top + s * 0.06), _stroke(const Color(0xFF3B2A1A), 1.2));
    final swing = math.sin(t * 2) * s * 0.01;
    c.drawRect(Rect.fromLTWH(sx + s * 0.03 + swing, f1.top + s * 0.075, s * 0.07, s * 0.06), _fill(const Color(0xFFC9A24B)));
    c.drawRect(Rect.fromLTWH(sx + s * 0.03 + swing, f1.top + s * 0.075, s * 0.07, s * 0.06), _stroke(const Color(0xFF3B2A1A), 0.8));
  }

  // ------------------------------------------------------------------
  // Public buildings
  // ------------------------------------------------------------------
  static void _bakery(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.68, s * 0.8, s * 0.56);
    final chim = Rect.fromLTWH(box.right - s * 0.22, box.top - s * 0.38, s * 0.1, s * 0.26);
    c.drawRect(chim, _fill(const Color(0xFF8D6E63)));
    _wall(c, box, const Color(0xFFF3DDB0));
    _gable(c, box, const Color(0xFFE67E22), s * 0.26);
    _smoke(c, chim.topCenter, t, s);
    _stripedAwning(c, Rect.fromLTWH(box.left + s * 0.05, box.top + s * 0.2, box.width - s * 0.1, s * 0.1), const Color(0xFFE53935), Colors.white, 6);
    _window(c, Rect.fromLTWH(box.left + s * 0.08, box.top + s * 0.33, s * 0.22, s * 0.14), lit: true);
    _door(c, Rect.fromLTWH(box.right - s * 0.28, box.bottom - s * 0.24, s * 0.16, s * 0.24));
    // bread sign
    c.drawCircle(Offset(box.center.dx, box.top + s * 0.1), s * 0.06, _fill(const Color(0xFFD4A24C)));
    c.drawOval(Rect.fromCenter(center: Offset(box.center.dx, box.top + s * 0.1), width: s * 0.08, height: s * 0.045), _fill(const Color(0xFF8D5524)));
  }

  static void _market(Canvas c, Rect r, double t, int seed) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.95);
    // stall counter
    final counter = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.3, s * 0.8, s * 0.2);
    // posts
    c.drawRect(Rect.fromLTWH(r.left + s * 0.12, r.bottom - s * 0.62, s * 0.04, s * 0.5), _fill(const Color(0xFF6B4423)));
    c.drawRect(Rect.fromLTWH(r.right - s * 0.16, r.bottom - s * 0.62, s * 0.04, s * 0.5), _fill(const Color(0xFF6B4423)));
    _wall(c, counter, const Color(0xFF9C6B3F));
    // goods
    final cols = [const Color(0xFFE53935), const Color(0xFF7CB342), const Color(0xFFFB8C00), const Color(0xFFFDD835)];
    for (var i = 0; i < 8; i++) {
      c.drawCircle(Offset(counter.left + s * 0.08 + i * s * 0.095, counter.top - s * 0.015), s * 0.04, _fill(cols[(i + seed) % 4]));
    }
    _stripedAwning(c, Rect.fromLTWH(r.left + s * 0.06, r.bottom - s * 0.68, s * 0.88, s * 0.14), const Color(0xFF1E88E5), Colors.white, 8);
    // crates
    c.drawRect(Rect.fromLTWH(r.left + s * 0.14, r.bottom - s * 0.14, s * 0.16, s * 0.1), _fill(const Color(0xFFB07A45)));
    c.drawRect(Rect.fromLTWH(r.right - s * 0.32, r.bottom - s * 0.14, s * 0.16, s * 0.1), _fill(const Color(0xFFB07A45)));
  }

  static void _inn(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.92);
    final box = Rect.fromLTWH(r.left + s * 0.07, r.bottom - s * 0.74, s * 0.86, s * 0.62);
    _wall(c, box, const Color(0xFF9A6A3F));
    // timber frame
    final tf = _stroke(const Color(0xFF4A3220), 1.4);
    c.drawLine(Offset(box.left + s * 0.2, box.top), Offset(box.left + s * 0.2, box.bottom), tf);
    c.drawLine(Offset(box.right - s * 0.2, box.top), Offset(box.right - s * 0.2, box.bottom), tf);
    c.drawLine(Offset(box.left, box.top + s * 0.28), Offset(box.right, box.top + s * 0.28), tf);
    _gable(c, box, const Color(0xFF4E342E), s * 0.28);
    _window(c, Rect.fromLTWH(box.left + s * 0.07, box.top + s * 0.07, s * 0.1, s * 0.15), lit: true);
    _window(c, Rect.fromLTWH(box.right - s * 0.17, box.top + s * 0.07, s * 0.1, s * 0.15), lit: true);
    _window(c, Rect.fromLTWH(box.left + s * 0.28, box.top + s * 0.07, s * 0.12, s * 0.15), lit: true);
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.26, s * 0.16, s * 0.26));
    // hanging sign
    final sway = math.sin(t * 2) * 1.2;
    c.drawLine(Offset(box.right - s * 0.06, box.top + s * 0.3), Offset(box.right + s * 0.06, box.top + s * 0.3), tf);
    c.drawRect(Rect.fromLTWH(box.right - s * 0.02 + sway, box.top + s * 0.3, s * 0.1, s * 0.09), _fill(const Color(0xFFF2CE7C)));
  }

  static void _blacksmith(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.62, s * 0.8, s * 0.5);
    final chim = Rect.fromLTWH(box.left + s * 0.12, box.top - s * 0.36, s * 0.13, s * 0.3);
    c.drawRect(chim, _fill(const Color(0xFF4E4A47)));
    _wall(c, box, const Color(0xFF7A756F));
    _gable(c, box, const Color(0xFF3A3A3F), s * 0.24);
    _smoke(c, chim.topCenter, t, s);
    // forge glow
    final glow = 0.6 + 0.4 * math.sin(t * 9);
    final fire = Rect.fromLTWH(box.right - s * 0.36, box.bottom - s * 0.3, s * 0.26, s * 0.3);
    c.drawRect(fire, _fill(const Color(0xFF2B2B2B)));
    c.drawRect(fire.deflate(s * 0.03), _fill(Color.lerp(const Color(0xFFFF6F00), const Color(0xFFFFD54F), glow)!));
    // anvil
    c.drawRect(Rect.fromLTWH(box.left + s * 0.1, box.bottom - s * 0.1, s * 0.16, s * 0.05), _fill(const Color(0xFF263238)));
    c.drawRect(Rect.fromLTWH(box.left + s * 0.14, box.bottom - s * 0.05, s * 0.08, s * 0.05), _fill(const Color(0xFF263238)));
    // sparks
    final k = (t * 3) % 1.0;
    c.drawCircle(Offset(box.left + s * 0.2 + k * s * 0.1, box.bottom - s * 0.14 - k * s * 0.12), s * 0.012,
        _fill(Colors.orangeAccent.withValues(alpha: 1 - k)));
  }

  static void _school(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.96);
    final box = Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.6, s * 0.92, s * 0.5);
    _wall(c, box, const Color(0xFFE9C46A));
    c.drawRect(Rect.fromLTWH(box.left - s * 0.02, box.top - s * 0.04, box.width + s * 0.04, s * 0.06), _fill(const Color(0xFFB5523B)));
    // bell tower
    final tower = Rect.fromLTWH(box.center.dx - s * 0.12, box.top - s * 0.34, s * 0.24, s * 0.34);
    _wall(c, tower, const Color(0xFFF1D88B));
    _gable(c, tower, const Color(0xFFB5523B), s * 0.18, overhang: 0.1);
    c.drawCircle(tower.center.translate(0, s * 0.02), s * 0.04, _fill(const Color(0xFFF2CE7C)));
    _flag(c, Offset(box.right - s * 0.1, box.top), s * 0.28, t, const Color(0xFF1E88E5));
    _windowGrid(c, Rect.fromLTWH(box.left + s * 0.04, box.top + s * 0.08, s * 0.32, s * 0.2), 1, 3);
    _windowGrid(c, Rect.fromLTWH(box.right - s * 0.36, box.top + s * 0.08, s * 0.32, s * 0.2), 1, 3);
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.26, s * 0.16, s * 0.26));
  }

  static void _clinic(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.94);
    final box = Rect.fromLTWH(r.left + s * 0.08, r.bottom - s * 0.74, s * 0.84, s * 0.62);
    _wall(c, box, const Color(0xFFF4F7F8));
    c.drawRect(Rect.fromLTWH(box.left - s * 0.02, box.top - s * 0.05, box.width + s * 0.04, s * 0.07), _fill(const Color(0xFF90A4AE)));
    // red cross
    final cc = Offset(box.center.dx, box.top + s * 0.17);
    c.drawRect(Rect.fromCenter(center: cc, width: s * 0.2, height: s * 0.07), _fill(const Color(0xFFE53935)));
    c.drawRect(Rect.fromCenter(center: cc, width: s * 0.07, height: s * 0.2), _fill(const Color(0xFFE53935)));
    _windowGrid(c, Rect.fromLTWH(box.left + s * 0.05, box.top + s * 0.34, s * 0.3, s * 0.14), 1, 2, glass: const Color(0xFFB3E5FC));
    _windowGrid(c, Rect.fromLTWH(box.right - s * 0.35, box.top + s * 0.34, s * 0.3, s * 0.14), 1, 2, glass: const Color(0xFFB3E5FC));
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.2, s * 0.16, s * 0.2), color: const Color(0xFF4FC3F7));
  }

  static void _fireStation(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.94);
    final box = Rect.fromLTWH(r.left + s * 0.06, r.bottom - s * 0.68, s * 0.88, s * 0.56);
    _wall(c, box, const Color(0xFFC0392B));
    c.drawRect(Rect.fromLTWH(box.left - s * 0.02, box.top - s * 0.05, box.width + s * 0.04, s * 0.07), _fill(const Color(0xFF424242)));
    // shutters
    for (var i = 0; i < 2; i++) {
      final d = Rect.fromLTWH(box.left + s * 0.08 + i * s * 0.38, box.bottom - s * 0.32, s * 0.32, s * 0.32);
      c.drawRect(d, _fill(const Color(0xFFCFD8DC)));
      for (var y = d.top + s * 0.04; y < d.bottom; y += s * 0.05) {
        c.drawLine(Offset(d.left, y), Offset(d.right, y), _stroke(const Color(0xFF90A4AE), 0.8));
      }
      c.drawRect(d, _stroke(const Color(0xFF263238), 1.2));
    }
    // flashing light
    c.drawCircle(Offset(box.center.dx, box.top - s * 0.09), s * 0.04, _fill(math.sin(t * 8) > 0 ? Colors.redAccent : Colors.blueAccent));
    final label = Rect.fromCenter(center: Offset(box.center.dx, box.top + s * 0.1), width: s * 0.3, height: s * 0.09);
    c.drawRect(label, _fill(const Color(0xFFFFEB3B)));
  }

  static void _library(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.96);
    final box = Rect.fromLTWH(r.left + s * 0.05, r.bottom - s * 0.62, s * 0.9, s * 0.5);
    _wall(c, box, const Color(0xFFE8DEC5));
    // pediment
    final p = Path()
      ..moveTo(box.left - s * 0.02, box.top)
      ..lineTo(box.center.dx, box.top - s * 0.24)
      ..lineTo(box.right + s * 0.02, box.top)
      ..close();
    c.drawPath(p, _fill(const Color(0xFFD7C9A7)));
    c.drawPath(p, _stroke(const Color(0xFF8E7F5E), 1.2));
    c.drawCircle(Offset(box.center.dx, box.top - s * 0.09), s * 0.04, _fill(const Color(0xFF8E7F5E)));
    _columns(c, Rect.fromLTWH(box.left + s * 0.08, box.top + s * 0.02, box.width - s * 0.16, box.height - s * 0.06), 5, const Color(0xFFF7F1E1));
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.22, s * 0.14, s * 0.22), color: const Color(0xFF5D4037));
    c.drawRect(Rect.fromLTWH(box.left, box.bottom - s * 0.02, box.width, s * 0.05), _fill(const Color(0xFFBDB09A)));
  }

  static void _clockTower(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.7);
    final box = Rect.fromLTWH(r.center.dx - s * 0.22, r.bottom - s * 1.2, s * 0.44, s * 1.1);
    _wall(c, box, const Color(0xFFC9B79C));
    // brick bands
    for (var y = box.top + s * 0.3; y < box.bottom; y += s * 0.26) {
      c.drawLine(Offset(box.left, y), Offset(box.right, y), _stroke(const Color(0xFF9C8B70), 1));
    }
    final belfry = Rect.fromLTWH(box.left - s * 0.04, box.top - s * 0.02, box.width + s * 0.08, s * 0.1);
    c.drawRect(belfry, _fill(const Color(0xFF7B6A52)));
    // pyramid roof
    final roof = Path()
      ..moveTo(belfry.left - s * 0.02, belfry.top)
      ..lineTo(box.center.dx, belfry.top - s * 0.3)
      ..lineTo(belfry.right + s * 0.02, belfry.top)
      ..close();
    c.drawPath(roof, _fill(const Color(0xFF2E7D6B)));
    c.drawPath(roof, _stroke(const Color(0xFF1B4D41), 1.2));
    // clock face
    final face = Offset(box.center.dx, box.top + s * 0.3);
    c.drawCircle(face, s * 0.15, _fill(const Color(0xFFF7F1E1)));
    c.drawCircle(face, s * 0.15, _stroke(const Color(0xFF4A3220), 2));
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      c.drawCircle(face + Offset(math.cos(a), math.sin(a)) * s * 0.12, 0.8, _fill(const Color(0xFF4A3220)));
    }
    final min = t * 0.5;
    final hour = min / 12;
    c.drawLine(face, face + Offset(math.cos(min * math.pi * 2 - math.pi / 2), math.sin(min * math.pi * 2 - math.pi / 2)) * s * 0.11,
        _stroke(const Color(0xFF212121), 1.4));
    c.drawLine(face, face + Offset(math.cos(hour * math.pi * 2 - math.pi / 2), math.sin(hour * math.pi * 2 - math.pi / 2)) * s * 0.07,
        _stroke(const Color(0xFF212121), 2));
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.2, s * 0.14, s * 0.2));
    _window(c, Rect.fromLTWH(box.center.dx - s * 0.04, box.top + s * 0.62, s * 0.08, s * 0.13));
  }

  static void _townHall(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.98);
    final box = Rect.fromLTWH(r.left + s * 0.03, r.bottom - s * 0.74, s * 0.94, s * 0.62);
    // dome
    final dc = Offset(box.center.dx, box.top - s * 0.02);
    final drum = Rect.fromCenter(center: dc.translate(0, -s * 0.04), width: s * 0.34, height: s * 0.1);
    c.drawRect(drum, _fill(const Color(0xFFEADFC8)));
    final dome = Rect.fromCenter(center: dc.translate(0, -s * 0.09), width: s * 0.36, height: s * 0.4);
    c.drawArc(dome, math.pi, math.pi, true, _fill(const Color(0xFF3E78B2)));
    c.drawArc(dome, math.pi, math.pi, true, _stroke(const Color(0xFF244B73), 1.2));
    c.drawCircle(dc.translate(0, -s * 0.3), s * 0.025, _fill(const Color(0xFFF2CE7C)));
    _flag(c, dc.translate(0, -s * 0.3), s * 0.2, t, const Color(0xFFE0A82E));
    _wall(c, box, const Color(0xFFDDCFB2));
    c.drawRect(Rect.fromLTWH(box.left - s * 0.02, box.top - s * 0.04, box.width + s * 0.04, s * 0.06), _fill(const Color(0xFFB9A785)));
    _columns(c, Rect.fromLTWH(box.left + s * 0.2, box.top + s * 0.06, box.width - s * 0.4, box.height - s * 0.12), 4, const Color(0xFFF7F1E1));
    _windowGrid(c, Rect.fromLTWH(box.left + s * 0.03, box.top + s * 0.1, s * 0.16, s * 0.3), 1, 1);
    _windowGrid(c, Rect.fromLTWH(box.right - s * 0.19, box.top + s * 0.1, s * 0.16, s * 0.3), 1, 1);
    _door(c, Rect.fromLTWH(box.center.dx - s * 0.09, box.bottom - s * 0.3, s * 0.18, s * 0.3), color: const Color(0xFF5D4037));
    // steps
    c.drawRect(Rect.fromLTWH(box.left + s * 0.18, box.bottom - s * 0.02, box.width - s * 0.36, s * 0.05), _fill(const Color(0xFFBDB09A)));
  }

  // ------------------------------------------------------------------
  // Parks
  // ------------------------------------------------------------------
  static void _garden(Canvas c, Rect r, double t, int col, int row) {
    final s = r.width;
    final inner = r.deflate(s * 0.08);
    c.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(s * 0.08)), _fill(const Color(0xFF5FA844)));
    c.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(s * 0.08)), _stroke(const Color(0xFF2E7D32), s * 0.07));
    final cols = [const Color(0xFFE91E63), const Color(0xFFFFEB3B), const Color(0xFFFFFFFF), const Color(0xFFAB47BC), const Color(0xFFFF7043)];
    final h = _hash(col, row);
    for (var i = 0; i < 9; i++) {
      final k = _hash(h, i + 3);
      final x = inner.left + s * 0.1 + (k % 100) / 100 * (inner.width - s * 0.2);
      final y = inner.top + s * 0.1 + ((k ~/ 100) % 100) / 100 * (inner.height - s * 0.2);
      final sway = math.sin(t * 2 + i) * 0.8;
      c.drawLine(Offset(x, y), Offset(x + sway, y + s * 0.07), _stroke(const Color(0xFF2E7D32), 1));
      c.drawCircle(Offset(x + sway, y), s * 0.04, _fill(cols[(k ~/ 7) % cols.length]));
      c.drawCircle(Offset(x + sway, y), s * 0.015, _fill(const Color(0xFFFFC107)));
    }
  }

  static void _fountain(Canvas c, Rect r, double t, {required bool grand}) {
    final s = r.width;
    // paved ground
    c.drawRect(r.deflate(s * 0.02), _fill(const Color(0xFFD8CFBD)));
    c.drawRect(r.deflate(s * 0.02), _stroke(const Color(0xFFA89E88), s * 0.03));
    final centre = r.center.translate(0, s * 0.06);
    final rx = grand ? s * 0.44 : s * 0.34;
    final ry = rx * 0.55;
    // basin
    c.drawOval(Rect.fromCenter(center: centre.translate(0, s * 0.04), width: rx * 2, height: ry * 2), _fill(const Color(0xFF8E8E8E)));
    c.drawOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2), _fill(const Color(0xFFBDBDBD)));
    c.drawOval(Rect.fromCenter(center: centre, width: rx * 1.7, height: ry * 1.7), _fill(const Color(0xFF4FC3F7)));
    // ripples
    for (var i = 0; i < 2; i++) {
      final k = ((t * 0.7) + i * 0.5) % 1.0;
      c.drawOval(Rect.fromCenter(center: centre, width: rx * 1.6 * k, height: ry * 1.6 * k),
          _stroke(Colors.white.withValues(alpha: 0.6 * (1 - k)), 1));
    }
    // pillar
    c.drawRect(Rect.fromCenter(center: centre.translate(0, -s * 0.1), width: s * 0.07, height: s * 0.24), _fill(const Color(0xFFA0A0A0)));
    if (grand) {
      c.drawOval(Rect.fromCenter(center: centre.translate(0, -s * 0.2), width: s * 0.34, height: s * 0.14), _fill(const Color(0xFFBDBDBD)));
      c.drawOval(Rect.fromCenter(center: centre.translate(0, -s * 0.2), width: s * 0.28, height: s * 0.1), _fill(const Color(0xFF4FC3F7)));
    }
    // water jets
    final jetTop = centre.translate(0, grand ? -s * 0.34 : -s * 0.22);
    final jets = grand ? 9 : 5;
    final water = _stroke(const Color(0xFFE1F5FE), math.max(1.2, s * 0.025));
    for (var i = 0; i < jets; i++) {
      final spread = (i - (jets - 1) / 2) / ((jets - 1) / 2);
      final pulse = 0.85 + 0.15 * math.sin(t * 6 + i);
      final end = jetTop.translate(spread * s * (grand ? 0.3 : 0.22), (grand ? s * 0.28 : s * 0.2) * pulse);
      final p = Path()
        ..moveTo(jetTop.dx, jetTop.dy)
        ..quadraticBezierTo(jetTop.dx + spread * s * 0.1, jetTop.dy - s * (grand ? 0.12 : 0.08) * pulse, end.dx, end.dy);
      c.drawPath(p, water);
    }
    // sparkles
    for (var i = 0; i < 4; i++) {
      final k = ((t * 1.3) + i * 0.25) % 1.0;
      c.drawCircle(jetTop.translate(math.sin(i * 2.1) * s * 0.18, k * s * 0.22), s * 0.012, _fill(Colors.white.withValues(alpha: 1 - k)));
    }
  }

  static void _playground(Canvas c, Rect r, double t) {
    final s = r.width;
    // rubber floor
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.04), Radius.circular(s * 0.1)), _fill(const Color(0xFFC95F4A)));
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.04), Radius.circular(s * 0.1)), _stroke(const Color(0xFF8E3C2B), 1.5));
    // sandbox
    final sand = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.32, s * 0.3, s * 0.2);
    c.drawRect(sand, _fill(const Color(0xFFF1D9A0)));
    c.drawRect(sand, _stroke(const Color(0xFF8D5B35), 2));
    c.drawRect(Rect.fromLTWH(sand.left + s * 0.04, sand.top + s * 0.05, s * 0.05, s * 0.05), _fill(const Color(0xFF29B6F6)));
    // slide
    final base = Offset(r.right - s * 0.3, r.bottom - s * 0.14);
    c.drawLine(base.translate(-s * 0.02, -s * 0.5), base.translate(-s * 0.02, 0), _stroke(const Color(0xFF455A64), 2));
    c.drawLine(base.translate(-s * 0.02, -s * 0.5), base.translate(s * 0.24, 0), _stroke(const Color(0xFFFFC107), s * 0.09));
    c.drawLine(base.translate(-s * 0.02, -s * 0.5), base.translate(s * 0.24, 0), _stroke(const Color(0xFFFFE082), s * 0.05));
    c.drawRect(Rect.fromLTWH(base.dx - s * 0.1, base.dy - s * 0.54, s * 0.16, s * 0.06), _fill(const Color(0xFF1E88E5)));
    // swings
    final top = r.top + s * 0.2;
    final lx = r.left + s * 0.16, rx = r.left + s * 0.62;
    final fr = _stroke(const Color(0xFF455A64), 2);
    c.drawLine(Offset(lx, top), Offset(lx - s * 0.02, r.top + s * 0.62), fr);
    c.drawLine(Offset(rx, top), Offset(rx + s * 0.02, r.top + s * 0.62), fr);
    c.drawLine(Offset(lx, top), Offset(rx, top), fr);
    final ang = math.sin(t * 2.4) * 0.5;
    for (var i = 0; i < 2; i++) {
      final px = lx + (rx - lx) * (0.3 + 0.4 * i);
      final len = s * 0.28;
      final seat = Offset(px + math.sin(ang * (i == 0 ? 1 : -1)) * len, top + math.cos(ang) * len);
      c.drawLine(Offset(px, top), seat, _stroke(Colors.black54, 0.8));
      c.drawRect(Rect.fromCenter(center: seat, width: s * 0.1, height: s * 0.03), _fill(const Color(0xFF8D6E63)));
      // tiny kid
      c.drawCircle(seat.translate(0, -s * 0.07), s * 0.025, _fill(const Color(0xFFFFCCBC)));
      c.drawRect(Rect.fromCenter(center: seat.translate(0, -s * 0.035), width: s * 0.045, height: s * 0.05), _fill(i == 0 ? const Color(0xFF42A5F5) : const Color(0xFFEC407A)));
    }
  }

  static void _pond(Canvas c, Rect r, double t) {
    final s = r.width;
    final water = Rect.fromLTWH(r.left + s * 0.06, r.top + s * 0.18, s * 0.88, s * 0.7);
    c.drawOval(water.inflate(s * 0.04), _fill(const Color(0xFF8D8D7A)));
    c.drawOval(water, _fill(const Color(0xFF4DB6E6)));
    c.drawOval(water.deflate(s * 0.08), _fill(const Color(0xFF6CC5EE)));
    for (var i = 0; i < 2; i++) {
      final k = ((t * 0.4) + i * 0.5) % 1.0;
      c.drawOval(Rect.fromCenter(center: water.center.translate(s * 0.1, 0), width: s * 0.5 * k, height: s * 0.3 * k),
          _stroke(Colors.white.withValues(alpha: 0.7 * (1 - k)), 1));
    }
    // lily pads
    for (final p in [const Offset(-0.25, 0.1), const Offset(0.2, 0.15), const Offset(-0.1, -0.15)]) {
      final o = water.center + Offset(p.dx * s, p.dy * s);
      c.drawOval(Rect.fromCenter(center: o, width: s * 0.16, height: s * 0.09), _fill(const Color(0xFF43A047)));
      c.drawCircle(o.translate(s * 0.02, -s * 0.01), s * 0.02, _fill(const Color(0xFFF8BBD0)));
    }
    // duck
    final dx = math.sin(t * 0.8) * s * 0.18;
    final d = water.center.translate(dx + s * 0.05, -s * 0.02 + math.sin(t * 3) * 1.2);
    c.drawOval(Rect.fromCenter(center: d, width: s * 0.17, height: s * 0.1), _fill(Colors.white));
    c.drawCircle(d.translate(s * 0.07 * (math.cos(t * 0.8) >= 0 ? 1 : -1), -s * 0.05), s * 0.04, _fill(Colors.white));
    c.drawCircle(d.translate(s * 0.09 * (math.cos(t * 0.8) >= 0 ? 1 : -1), -s * 0.05), s * 0.015, _fill(const Color(0xFFFFA000)));
    // reeds
    final reed = _stroke(const Color(0xFF558B2F), 1.4);
    for (var i = 0; i < 3; i++) {
      final x = r.left + s * (0.08 + i * 0.03);
      c.drawLine(Offset(x, r.bottom - s * 0.14), Offset(x + math.sin(t * 2 + i) * 1.5, r.bottom - s * 0.34), reed);
    }
  }

  static void _football(Canvas c, Rect r, double t) {
    final s = r.width;
    final f = r.deflate(s * 0.03);
    c.drawRect(f, _fill(const Color(0xFF3F9A3B)));
    for (var i = 0; i < 5; i++) {
      if (i.isEven) {
        c.drawRect(Rect.fromLTWH(f.left + f.width * i / 5, f.top, f.width / 5, f.height), _fill(const Color(0xFF47A842)));
      }
    }
    final line = _stroke(Colors.white.withValues(alpha: 0.9), 1.4);
    c.drawRect(f.deflate(s * 0.04), line);
    c.drawLine(Offset(f.center.dx, f.top + s * 0.04), Offset(f.center.dx, f.bottom - s * 0.04), line);
    c.drawCircle(f.center, s * 0.1, line);
    // goals
    c.drawRect(Rect.fromLTWH(f.left + s * 0.04, f.center.dy - s * 0.1, s * 0.07, s * 0.2), _stroke(Colors.white, 1.6));
    c.drawRect(Rect.fromLTWH(f.right - s * 0.11, f.center.dy - s * 0.1, s * 0.07, s * 0.2), _stroke(Colors.white, 1.6));
    // players + ball
    final bx = f.center.dx + math.sin(t * 1.6) * s * 0.28;
    final by = f.center.dy + math.sin(t * 2.3) * s * 0.18;
    final players = <List<dynamic>>[
      [const Offset(-0.18, -0.12), const Color(0xFFE53935)],
      [const Offset(-0.3, 0.14), const Color(0xFFE53935)],
      [const Offset(0.18, 0.1), const Color(0xFF1E88E5)],
      [const Offset(0.3, -0.14), const Color(0xFF1E88E5)],
    ];
    var i = 0;
    for (final p in players) {
      final o = f.center + Offset((p[0] as Offset).dx * s + math.sin(t * 1.5 + i) * s * 0.04, (p[0] as Offset).dy * s + math.cos(t * 1.3 + i) * s * 0.03);
      c.drawCircle(o.translate(0, -s * 0.045), s * 0.025, _fill(const Color(0xFFFFCCBC)));
      c.drawRect(Rect.fromCenter(center: o, width: s * 0.05, height: s * 0.06), _fill(p[1] as Color));
      i++;
    }
    c.drawCircle(Offset(bx, by), s * 0.02, _fill(Colors.white));
    c.drawCircle(Offset(bx, by), s * 0.02, _stroke(Colors.black87, 0.6));
  }

  // ------------------------------------------------------------------
  // Decorations
  // ------------------------------------------------------------------
  static void _tree(Canvas c, Rect r, double t, int seed) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.6);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.center.dx - s * 0.05, r.bottom - s * 0.4, s * 0.1, s * 0.32), const Radius.circular(2)), _fill(const Color(0xFF6B4423)));
    final sway = math.sin(t * 1.4 + seed) * s * 0.012;
    final cx = r.center.dx + sway;
    final cy = r.bottom - s * 0.56;
    c.drawCircle(Offset(cx - s * 0.14, cy + s * 0.05), s * 0.2, _fill(const Color(0xFF2E7D32)));
    c.drawCircle(Offset(cx + s * 0.14, cy + s * 0.05), s * 0.2, _fill(const Color(0xFF2E7D32)));
    c.drawCircle(Offset(cx, cy - s * 0.08), s * 0.24, _fill(const Color(0xFF3FA34D)));
    c.drawCircle(Offset(cx - s * 0.06, cy - s * 0.14), s * 0.1, _fill(const Color(0xFF66BB6A).withValues(alpha: 0.8)));
  }

  static void _pine(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.55);
    c.drawRect(Rect.fromLTWH(r.center.dx - s * 0.04, r.bottom - s * 0.22, s * 0.08, s * 0.14), _fill(const Color(0xFF5D4037)));
    final sway = math.sin(t * 1.6) * s * 0.01;
    for (var i = 0; i < 3; i++) {
      final yb = r.bottom - s * (0.18 + i * 0.22);
      final w = s * (0.36 - i * 0.07);
      final p = Path()
        ..moveTo(r.center.dx - w + sway * i, yb)
        ..lineTo(r.center.dx + sway * (i + 1), yb - s * 0.3)
        ..lineTo(r.center.dx + w + sway * i, yb)
        ..close();
      c.drawPath(p, _fill(i == 0 ? const Color(0xFF1B6B3A) : (i == 1 ? const Color(0xFF248A47) : const Color(0xFF2FA555))));
    }
  }

  static void _flowers(Canvas c, Rect r, double t, int col, int row) {
    final s = r.width;
    final bed = Rect.fromLTWH(r.left + s * 0.14, r.bottom - s * 0.42, s * 0.72, s * 0.32);
    c.drawRRect(RRect.fromRectAndRadius(bed, Radius.circular(s * 0.1)), _fill(const Color(0xFF6B4A32)));
    final cols = [const Color(0xFFE91E63), const Color(0xFFFFEB3B), const Color(0xFFFFFFFF), const Color(0xFFAB47BC), const Color(0xFFFF7043)];
    final h = _hash(col, row);
    for (var i = 0; i < 7; i++) {
      final x = bed.left + s * 0.08 + i * (bed.width - s * 0.16) / 6;
      final y = bed.top + s * 0.06 + (i.isEven ? 0 : s * 0.08);
      final sway = math.sin(t * 2 + i) * 0.8;
      c.drawLine(Offset(x, y + s * 0.1), Offset(x + sway, y), _stroke(const Color(0xFF2E7D32), 1.1));
      c.drawCircle(Offset(x + sway, y), s * 0.045, _fill(cols[(h + i) % cols.length]));
      c.drawCircle(Offset(x + sway, y), s * 0.016, _fill(const Color(0xFFFFC107)));
    }
  }

  static void _bench(Canvas c, Rect r) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.6);
    final wood = _fill(const Color(0xFF9C6B3F));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.2, r.bottom - s * 0.4, s * 0.6, s * 0.07), wood);
    c.drawRect(Rect.fromLTWH(r.left + s * 0.2, r.bottom - s * 0.3, s * 0.6, s * 0.07), wood);
    c.drawRect(Rect.fromLTWH(r.left + s * 0.2, r.bottom - s * 0.2, s * 0.6, s * 0.06), _fill(const Color(0xFFB07A45)));
    final leg = _fill(const Color(0xFF37474F));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.24, r.bottom - s * 0.2, s * 0.05, s * 0.12), leg);
    c.drawRect(Rect.fromLTWH(r.right - s * 0.29, r.bottom - s * 0.2, s * 0.05, s * 0.12), leg);
  }

  static void _lamp(Canvas c, Rect r, double t) {
    final s = r.width;
    final top = Offset(r.center.dx, r.bottom - s * 0.7);
    final glow = 0.25 + 0.1 * math.sin(t * 3);
    c.drawCircle(
      top,
      s * 0.34,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFE082).withValues(alpha: glow + 0.2), const Color(0x00FFE082)])
            .createShader(Rect.fromCircle(center: top, radius: s * 0.34)),
    );
    c.drawRect(Rect.fromLTWH(r.center.dx - s * 0.03, top.dy, s * 0.06, s * 0.6), _fill(const Color(0xFF37474F)));
    c.drawRect(Rect.fromLTWH(r.center.dx - s * 0.09, r.bottom - s * 0.1, s * 0.18, s * 0.05), _fill(const Color(0xFF263238)));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top, width: s * 0.14, height: s * 0.15), Radius.circular(s * 0.04)),
        _fill(const Color(0xFFFFF176)));
    c.drawRect(Rect.fromCenter(center: top.translate(0, -s * 0.09), width: s * 0.18, height: s * 0.04), _fill(const Color(0xFF263238)));
  }

  static void _well(Canvas c, Rect r) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.7);
    final base = Rect.fromLTWH(r.center.dx - s * 0.22, r.bottom - s * 0.36, s * 0.44, s * 0.26);
    _wall(c, base, const Color(0xFF9E9A94), radius: 4);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(base.left, base.top + s * 0.08 * (i + 1)), Offset(base.right, base.top + s * 0.08 * (i + 1)), _stroke(const Color(0xFF6D6A65), 0.7));
    }
    c.drawOval(Rect.fromLTWH(base.left, base.top - s * 0.04, base.width, s * 0.1), _fill(const Color(0xFF263238)));
    final post = _fill(const Color(0xFF6B4423));
    c.drawRect(Rect.fromLTWH(base.left + s * 0.02, base.top - s * 0.3, s * 0.04, s * 0.3), post);
    c.drawRect(Rect.fromLTWH(base.right - s * 0.06, base.top - s * 0.3, s * 0.04, s * 0.3), post);
    final roof = Path()
      ..moveTo(base.left - s * 0.04, base.top - s * 0.28)
      ..lineTo(base.center.dx, base.top - s * 0.42)
      ..lineTo(base.right + s * 0.04, base.top - s * 0.28)
      ..close();
    c.drawPath(roof, _fill(const Color(0xFFB5523B)));
    c.drawLine(Offset(base.center.dx, base.top - s * 0.3), Offset(base.center.dx, base.top - s * 0.12), _stroke(Colors.black54, 0.8));
    c.drawRect(Rect.fromCenter(center: Offset(base.center.dx, base.top - s * 0.1), width: s * 0.06, height: s * 0.05), _fill(const Color(0xFF8D6E63)));
  }

  static void _statue(Canvas c, Rect r) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.6);
    final ped = Rect.fromLTWH(r.center.dx - s * 0.2, r.bottom - s * 0.28, s * 0.4, s * 0.2);
    _wall(c, ped, const Color(0xFFB8B2A8));
    c.drawRect(Rect.fromLTWH(ped.left - s * 0.03, ped.bottom - s * 0.04, ped.width + s * 0.06, s * 0.05), _fill(const Color(0xFF9E978A)));
    final stone = _fill(const Color(0xFF8E8A84));
    final cx = r.center.dx;
    // body
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.08, ped.top - s * 0.34, s * 0.16, s * 0.34), Radius.circular(s * 0.04)), stone);
    // head + helmet
    c.drawCircle(Offset(cx, ped.top - s * 0.4), s * 0.06, stone);
    c.drawRect(Rect.fromLTWH(cx - s * 0.065, ped.top - s * 0.47, s * 0.13, s * 0.04), _fill(const Color(0xFF6F6B66)));
    // sword + shield
    c.drawLine(Offset(cx + s * 0.1, ped.top - s * 0.1), Offset(cx + s * 0.1, ped.top - s * 0.5), _stroke(const Color(0xFFD7D2C8), s * 0.03));
    c.drawLine(Offset(cx + s * 0.05, ped.top - s * 0.18), Offset(cx + s * 0.15, ped.top - s * 0.18), _stroke(const Color(0xFFD7D2C8), s * 0.02));
    final shield = Path()
      ..moveTo(cx - s * 0.18, ped.top - s * 0.28)
      ..lineTo(cx - s * 0.06, ped.top - s * 0.28)
      ..lineTo(cx - s * 0.06, ped.top - s * 0.12)
      ..quadraticBezierTo(cx - s * 0.12, ped.top - s * 0.04, cx - s * 0.18, ped.top - s * 0.12)
      ..close();
    c.drawPath(shield, _fill(const Color(0xFFB0A99C)));
    c.drawPath(shield, _stroke(const Color(0xFF6F6B66), 1));
  }

  static void _windmill(Canvas c, Rect r, double t) {
    final s = r.width;
    _groundShadow(c, r, wf: 0.7);
    final bw = s * 0.52, tw = s * 0.3;
    final bottom = r.bottom - s * 0.1;
    final top = bottom - s * 0.8;
    final body = Path()
      ..moveTo(r.center.dx - bw / 2, bottom)
      ..lineTo(r.center.dx - tw / 2, top)
      ..lineTo(r.center.dx + tw / 2, top)
      ..lineTo(r.center.dx + bw / 2, bottom)
      ..close();
    c.drawPath(body, _fill(const Color(0xFFEFE3CB)));
    c.drawPath(body, _stroke(const Color(0xFF8E7F5E), 1.4));
    final cone = Path()
      ..moveTo(r.center.dx - tw / 2 - s * 0.04, top)
      ..lineTo(r.center.dx, top - s * 0.24)
      ..lineTo(r.center.dx + tw / 2 + s * 0.04, top)
      ..close();
    c.drawPath(cone, _fill(const Color(0xFFB5523B)));
    c.drawPath(cone, _stroke(const Color(0xFF7A3524), 1.2));
    _door(c, Rect.fromLTWH(r.center.dx - s * 0.06, bottom - s * 0.2, s * 0.12, s * 0.2));
    _window(c, Rect.fromLTWH(r.center.dx - s * 0.04, bottom - s * 0.5, s * 0.08, s * 0.1));
    // blades
    final hub = Offset(r.center.dx, top + s * 0.05);
    c.save();
    c.translate(hub.dx, hub.dy);
    c.rotate(t * 0.9);
    for (var i = 0; i < 4; i++) {
      c.save();
      c.rotate(i * math.pi / 2);
      c.drawLine(Offset.zero, Offset(0, -s * 0.5), _stroke(const Color(0xFF6B4423), s * 0.03));
      c.drawRect(Rect.fromLTWH(s * 0.015, -s * 0.5, s * 0.12, s * 0.3), _fill(Colors.white.withValues(alpha: 0.92)));
      c.drawRect(Rect.fromLTWH(s * 0.015, -s * 0.5, s * 0.12, s * 0.3), _stroke(const Color(0xFF8E7F5E), 0.8));
      c.restore();
    }
    c.restore();
    c.drawCircle(hub, s * 0.04, _fill(const Color(0xFF4A3220)));
  }
}

/// Little preview used on the build-menu cards.
class BuildingPreview extends StatelessWidget {
  final String id;
  final double size;
  final Animation<double>? time;
  const BuildingPreview({super.key, required this.id, this.size = 56, this.time});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.5,
      child: CustomPaint(painter: _PreviewPainter(id, size, time)),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final String id;
  final double tile;
  final Animation<double>? time;
  _PreviewPainter(this.id, this.tile, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, size.height - tile, tile, tile);
    final t = (time?.value ?? 0) * 1000;
    final side = TownArt.east | TownArt.west;
    TownArt.drawGround(canvas, r, 0, 0);
    if (TownArt.isRoadId(id)) {
      TownArt.drawRoad(canvas, id, r, side, 1, 1);
    } else if (TownArt.isWaterId(id)) {
      TownArtX.drawWater(canvas, id, r, side, t, 1, 1);
    } else if (id == 'rail') {
      TownArtX.drawRail(canvas, r, side, 1, 1);
    } else if (TownArt.isOnWaterId(id)) {
      TownArtX.drawWater(canvas, 'river', r, side, t, 1, 1);
      TownArt.draw(canvas, id, r, t, roadMask: side);
    } else if (id == 'train' || id == 'train_wagon') {
      TownArtX.drawRail(canvas, r, side, 1, 1);
      TownArt.draw(canvas, id, r, t, roadMask: side);
    } else {
      TownArt.draw(canvas, id, r, t, roadMask: side);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.id != id || old.tile != tile;
}
