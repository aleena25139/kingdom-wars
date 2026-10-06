// Procedural (code-drawn) character art. Used as a fallback whenever a
// character's PNG is missing from assets/ — this is why Lizards / Monsters
// (and any other unit whose art file isn't shipped yet) used to be invisible
// in battle: there was nothing to draw. Everything here is painted on a
// transparent canvas (no background box at all) in a 100x100 design space,
// then scaled to whatever size the caller asks for.
//
// The enemies get real attack poses:
//   Lizard  - style 0: BITE  (head lunges, jaws open wide showing teeth)
//             style 1: CLAW  (front leg rears up and rakes with 3 claws)
//   Monster - style 0: CLAW  (huge arm winds up and slams down, claws out)
//             style 1: BITE  (head lunges, roaring mouth full of fangs)
// [attack] is the 0..1 progress of the current strike (0 = not attacking),
// [walk] is a running phase in radians that drives the leg/tail swing.
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CreatureKind { lizard, monster, skeleton, skeletonArcher, archer, knight, mage, dragon, panda }

class CreaturePainter {
  CreaturePainter._();

  static const Map<String, CreatureKind> _bySprite = {
    'lizard': CreatureKind.lizard,
    'monster': CreatureKind.monster,
    'skeleton': CreatureKind.skeleton,
    'skeleton_archer': CreatureKind.skeletonArcher,
    'archer': CreatureKind.archer,
    'knight': CreatureKind.knight,
    'mage': CreatureKind.mage,
    'good_dragon': CreatureKind.dragon,
    'panda_warrior': CreatureKind.panda,
  };

  static CreatureKind? kindFor(String spriteName) => _bySprite[spriteName];

  /// Paints [kind] into a [size]-sized box at the canvas origin. Characters
  /// are drawn facing right; pass [facingLeft] to mirror them.
  static void paint(
    Canvas canvas,
    Size size,
    CreatureKind kind, {
    double walk = 0,
    double attack = 0,
    int style = 0,
    bool facingLeft = false,
  }) {
    canvas.save();
    canvas.scale(size.width / 100.0, size.height / 100.0);
    if (facingLeft) {
      canvas.translate(100.0, 0.0);
      canvas.scale(-1.0, 1.0);
    }
    final p = attack.clamp(0.0, 1.0);
    final s = p > 0 ? math.sin(p * math.pi) : 0.0; // 0 -> 1 -> 0 across a strike
    switch (kind) {
      case CreatureKind.lizard:
        _lizard(canvas, walk, p, s, style);
        break;
      case CreatureKind.monster:
        _monster(canvas, walk, p, s, style);
        break;
      case CreatureKind.skeleton:
        _skeleton(canvas, walk, p, s, false);
        break;
      case CreatureKind.skeletonArcher:
        _skeleton(canvas, walk, p, s, true);
        break;
      case CreatureKind.archer:
        _archer(canvas);
        break;
      case CreatureKind.knight:
        _knight(canvas);
        break;
      case CreatureKind.mage:
        _mage(canvas);
        break;
      case CreatureKind.dragon:
        _dragon(canvas, walk);
        break;
      case CreatureKind.panda:
        _panda(canvas);
        break;
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------
  // Tiny drawing helpers
  // ------------------------------------------------------------------
  static Paint _f(Color c) => Paint()..color = c;

  static Paint _s(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static void _poly(Canvas c, List<Offset> pts, Paint p) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    c.drawPath(path, p);
  }

  /// A row of [n] triangular teeth along from->to, each pointing along [dir].
  static void _teeth(Canvas c, Offset from, Offset to, int n, double len, Offset dir, Paint p) {
    final d = to - from;
    for (var i = 0; i < n; i++) {
      final a = from + d * (i / n);
      final b = from + d * ((i + 1) / n);
      final tip = (a + b) / 2 + dir * len;
      _poly(c, [a, b, tip], p);
    }
  }

  /// A fan of [n] sharp claws radiating from [base] around [angle].
  static void _claws(Canvas c, Offset base, double angle, double len, int n, double spread, Paint p) {
    for (var i = 0; i < n; i++) {
      final a = angle + (i - (n - 1) / 2) * spread;
      final dir = Offset(math.cos(a), math.sin(a));
      final perp = Offset(-math.sin(a), math.cos(a));
      _poly(c, [base + perp * 1.5, base - perp * 1.5, base + dir * len], p);
    }
  }

  /// Windup -> slam -> recover arm angle (radians, clockwise from +x).
  static double _armAngle(double p, double idle) {
    if (p <= 0) return idle;
    if (p < 0.35) return _lerp(idle, -1.1, p / 0.35);
    if (p < 0.7) return _lerp(-1.1, 0.95, (p - 0.35) / 0.35);
    return _lerp(0.95, idle, (p - 0.7) / 0.3);
  }

  static const Color _tooth = Color(0xFFFFFFF0);
  static const Color _clawColor = Color(0xFFFFF3D6);

  // ------------------------------------------------------------------
  // LIZARD  (fast skirmisher: bites with teeth, rakes with claws)
  // ------------------------------------------------------------------
  static void _lizard(Canvas c, double w, double p, double s, int style) {
    const body = Color(0xFF43A047);
    const dark = Color(0xFF2E7D32);
    const belly = Color(0xFFC5E1A5);
    const jawColor = Color(0xFF7CB342);
    final bite = style == 0;
    final clawS = bite ? 0.0 : s;
    final biteS = bite ? s : s * 0.3;
    final lunge = biteS * 10;
    final bob = math.sin(w * 2) * 1.2;

    // Tail (wags as it runs).
    final wag = math.sin(w) * 7;
    final tail = Path()
      ..moveTo(30, 60 + bob)
      ..quadraticBezierTo(14, 68 + wag, 3, 54 + wag * 0.6);
    c.drawPath(tail, _s(dark, 8));
    c.drawPath(tail, _s(body, 4));

    void leg(double hx, double phase, Color col) {
      final swing = math.sin(w + phase) * 6;
      final hip = Offset(hx + lunge * 0.4, 66 + bob);
      final foot = Offset(hx + swing, 87);
      final knee = Offset((hip.dx + foot.dx) / 2 + 4, 78);
      final path = Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(foot.dx, foot.dy);
      c.drawPath(path, _s(col, 5));
      _claws(c, foot, 0.5, 5, 3, 0.45, _f(_clawColor));
    }

    // Far-side legs first, then body, then near-side legs.
    leg(34, math.pi, const Color(0xFF276B2B));
    leg(58, 0, const Color(0xFF276B2B));

    final bodyCenter = Offset(46 + lunge * 0.5, 60 + bob);
    c.drawOval(Rect.fromCenter(center: bodyCenter, width: 54, height: 28), _f(body));
    c.drawOval(Rect.fromCenter(center: bodyCenter + const Offset(2, 7), width: 40, height: 10), _f(belly));
    for (final dx in [-10.0, 0.0, 10.0]) {
      c.drawCircle(bodyCenter + Offset(dx, -6), 2.4, _f(dark));
    }
    // Back spikes.
    for (final x in [32.0, 39.0, 46.0, 53.0, 60.0]) {
      final k = (x - 46) / 27;
      final topY = 60 + bob - 14 * math.sqrt(math.max(0.0, 1 - k * k));
      final sx = x + lunge * 0.5;
      _poly(c, [Offset(sx - 3, topY + 1.5), Offset(sx + 3, topY + 1.5), Offset(sx, topY - 7)], _f(dark));
    }

    leg(30, 0, dark);
    // Near front leg — this is the one that claws when style == 1.
    if (clawS > 0.02) {
      final hip = Offset(62 + lunge * 0.4, 66 + bob);
      final foot = Offset(62 + 8 + 22 * clawS, 87 - 30 * clawS);
      final knee = Offset(hip.dx + 10 * clawS + 2, hip.dy + 8 - 6 * clawS);
      final path = Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(foot.dx, foot.dy);
      c.drawPath(path, _s(dark, 5.5));
      _claws(c, foot, -0.25, 9, 3, 0.4, _f(_clawColor));
    } else {
      leg(62, math.pi, dark);
    }

    // Head.
    final hx = lunge;
    final open = 0.12 + 0.62 * biteS + 0.15 * clawS;
    final pivot = Offset(64 + hx, 57 + bob);
    c.drawCircle(Offset(63 + hx, 53 + bob), 9, _f(body)); // neck
    if (open > 0.2) {
      final upFront = Offset(90 + hx, 55 + bob);
      final loTip = pivot + Offset(math.cos(open), math.sin(open)) * 26;
      _poly(c, [pivot, upFront, loTip], _f(const Color(0xFF7B1E1E)));
    }
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(open);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(0, -1, 26, 4.5), const Radius.circular(2.5)),
      _f(jawColor),
    );
    _teeth(c, const Offset(4, -1), const Offset(25, -1), 5, 3.8, const Offset(0, -1), _f(_tooth));
    c.restore();
    final upper = Path()
      ..moveTo(62 + hx, 45 + bob)
      ..quadraticBezierTo(88 + hx, 40 + bob, 93 + hx, 51 + bob)
      ..lineTo(92 + hx, 56 + bob)
      ..lineTo(64 + hx, 58 + bob)
      ..close();
    c.drawPath(upper, _f(body));
    _teeth(c, Offset(68 + hx, 57.6 + bob), Offset(91 + hx, 55.6 + bob), 5, 4.2 + 2.5 * biteS, const Offset(0, 1),
        _f(_tooth));
    // Eye, brow, nostril.
    c.drawCircle(Offset(74 + hx, 48 + bob), 3.4, _f(const Color(0xFFFFEB3B)));
    c.drawOval(Rect.fromCenter(center: Offset(74.6 + hx, 48 + bob), width: 1.6, height: 5), _f(Colors.black));
    c.drawLine(Offset(69 + hx, 43.5 + bob), Offset(79 + hx, 46 + bob), _s(dark, 2));
    c.drawCircle(Offset(89 + hx, 48 + bob), 1.1, _f(dark));

    // Claw-rake slash marks in front of the lizard.
    if (clawS > 0.2) {
      final sp = _s(Colors.white.withValues(alpha: clawS.clamp(0.0, 1.0)), 2.2);
      for (var i = 0; i < 3; i++) {
        final path = Path()
          ..moveTo(88 + hx + i * 2.0, 34 + i * 7.0 + bob)
          ..quadraticBezierTo(101 + hx, 45 + i * 7.0 + bob, 93 + hx + i * 2.0, 59 + i * 7.0 + bob);
        c.drawPath(path, sp);
      }
    }
  }

  // ------------------------------------------------------------------
  // MONSTER  (slow heavy brute: slams with claws, chomps with fangs)
  // ------------------------------------------------------------------
  static void _monster(Canvas c, double w, double p, double s, int style) {
    const body = Color(0xFF7B3FA0);
    const dark = Color(0xFF4A2068);
    const belly = Color(0xFFB98BD1);
    const horn = Color(0xFFF1E4C3);
    final clawStyle = style == 0;
    final clawP = clawStyle ? p : 0.0;
    final biteS = clawStyle ? s * 0.35 : s;
    final lunge = (clawStyle ? s * 4 : s * 8);
    final bob = math.sin(w * 2) * 1.5;

    // Legs.
    for (var i = 0; i < 2; i++) {
      final hipX = i == 0 ? 42.0 : 58.0;
      final swing = math.sin(w + (i == 0 ? 0 : math.pi)) * 5;
      final hip = Offset(hipX + lunge * 0.3, 70 + bob);
      final foot = Offset(hipX + swing, 91);
      c.drawLine(hip, foot, _s(dark, 13));
      c.drawOval(Rect.fromCenter(center: foot + const Offset(3, 1), width: 17, height: 8), _f(dark));
      _claws(c, foot + const Offset(10, 1), 0.0, 5, 3, 0.4, _f(horn));
    }

    // Back arm (hangs and sways).
    final backShoulder = Offset(38 + lunge * 0.5, 46 + bob);
    final backA = 1.35 + math.sin(w + math.pi) * 0.15;
    final backHand = backShoulder + Offset(math.cos(backA), math.sin(backA)) * 25;
    c.drawLine(backShoulder, backHand, _s(dark, 10));
    c.drawCircle(backHand, 5.5, _f(dark));
    _claws(c, backHand, backA, 8, 3, 0.45, _f(horn));

    // Torso + belly + back spikes.
    final torso = Offset(50 + lunge * 0.5, 56 + bob);
    c.drawOval(Rect.fromCenter(center: torso, width: 50, height: 54), _f(body));
    c.drawOval(Rect.fromCenter(center: torso + const Offset(3, 6), width: 28, height: 30), _f(belly));
    for (final pt in [const Offset(30, 42), const Offset(33, 33), const Offset(39, 27)]) {
      final o = pt + Offset(lunge * 0.5, bob);
      _poly(c, [o + const Offset(-4, 3), o + const Offset(4, 4), o + const Offset(-4, -8)], _f(dark));
    }

    // Head.
    final head = Offset(56 + lunge, 27 + bob);
    _poly(c, [head + const Offset(-11, -8), head + const Offset(-5, -13), head + const Offset(-16, -25)], _f(horn));
    _poly(c, [head + const Offset(9, -13), head + const Offset(14, -6), head + const Offset(16, -24)], _f(horn));
    c.drawCircle(head, 15, _f(body));
    // Eyes + angry brows.
    for (final e in [head + const Offset(-5, -1), head + const Offset(6, -2)]) {
      c.drawCircle(e, 3.4, _f(const Color(0xFFFF1744)));
      c.drawCircle(e + const Offset(0.6, 0.4), 1.3, _f(Colors.black));
    }
    c.drawLine(head + const Offset(-10, -8), head + const Offset(-2, -3.5), _s(dark, 2.8));
    c.drawLine(head + const Offset(11, -9), head + const Offset(3, -4.5), _s(dark, 2.8));
    // Mouth: opens wide on a bite; always shows fangs.
    final mouthH = 4 + 11 * biteS;
    final mc = head + Offset(1, 9 + mouthH * 0.15);
    c.drawOval(Rect.fromCenter(center: mc, width: 22, height: mouthH), _f(const Color(0xFF5D0F1E)));
    final top = mc.dy - mouthH / 2;
    final bot = mc.dy + mouthH / 2;
    _teeth(c, Offset(mc.dx - 9, top + 0.6), Offset(mc.dx + 9, top + 0.6), 5, 3.4 + 2 * biteS, const Offset(0, 1), _f(_tooth));
    _teeth(c, Offset(mc.dx - 8, bot - 0.6), Offset(mc.dx + 8, bot - 0.6), 4, 3.0, const Offset(0, -1), _f(_tooth));
    _poly(c, [Offset(mc.dx - 10, top), Offset(mc.dx - 6, top), Offset(mc.dx - 8, top + 8 + 3 * biteS)], _f(_tooth));
    _poly(c, [Offset(mc.dx + 6, top), Offset(mc.dx + 10, top), Offset(mc.dx + 8, top + 8 + 3 * biteS)], _f(_tooth));

    // Front arm: the big claw slam.
    final shoulder = Offset(63 + lunge * 0.7, 46 + bob);
    final a = _armAngle(clawP, 1.35 + math.sin(w) * 0.1);
    final hand = shoulder + Offset(math.cos(a), math.sin(a)) * 27;
    if (clawP > 0.35 && clawP < 0.72) {
      c.drawArc(Rect.fromCircle(center: shoulder, radius: 31), -1.0, a + 1.0, false,
          _s(Colors.white.withValues(alpha: 0.55), 3));
    }
    c.drawLine(shoulder, hand, _s(body, 12));
    c.drawLine(shoulder, Offset.lerp(shoulder, hand, 0.55)!, _s(dark, 3));
    c.drawCircle(hand, 6.5, _f(body));
    _claws(c, hand, a, 11, 3, 0.42, _f(_clawColor));
  }

  // ------------------------------------------------------------------
  // SKELETON / SKELETON ARCHER
  // ------------------------------------------------------------------
  static void _skeleton(Canvas c, double w, double p, double s, bool archer) {
    const bone = Color(0xFFEFE7D0);
    const shade = Color(0xFF8E8468);
    final lunge = archer ? 0.0 : s * 5;
    final bob = math.sin(w * 2) * 1.2;
    final hips = Offset(48 + lunge * 0.4, 64 + bob);

    for (var i = 0; i < 2; i++) {
      final swing = math.sin(w + (i == 0 ? 0 : math.pi)) * 7;
      final foot = Offset(hips.dx - 2 + i * 6 + swing, 92);
      final knee = Offset((hips.dx + foot.dx) / 2 + 3, 78);
      final path = Path()
        ..moveTo(hips.dx, hips.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(foot.dx, foot.dy);
      c.drawPath(path, _s(bone, 4.2));
      c.drawCircle(knee, 2.6, _f(bone));
      c.drawLine(foot, foot + const Offset(6, 0), _s(bone, 3.4));
    }
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(hips.dx - 8, hips.dy - 4, hips.dx + 8, hips.dy + 3), const Radius.circular(2)),
      _f(bone),
    );
    final neck = Offset(49 + lunge * 0.6, 40 + bob);
    c.drawLine(hips, neck, _s(bone, 3.6));
    for (var i = 0; i < 4; i++) {
      final y = 44 + i * 5.2 + bob;
      c.drawLine(Offset(40 + lunge * 0.6, y), Offset(58 + lunge * 0.6, y), _s(bone, 2.6));
    }
    c.drawLine(Offset(39 + lunge * 0.6, 41 + bob), Offset(59 + lunge * 0.6, 41 + bob), _s(bone, 3.6));

    // Back arm.
    final bs = Offset(40 + lunge * 0.6, 43 + bob);
    c.drawLine(bs, Offset(34 + math.sin(w + math.pi) * 3, 62 + bob), _s(bone, 3.2));

    // Skull.
    final sk = Offset(52 + lunge, 26 + bob);
    c.drawCircle(sk, 11, _f(bone));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(sk.dx - 6, sk.dy + 6, sk.dx + 7, sk.dy + 13), const Radius.circular(2)),
      _f(bone),
    );
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(sk.dx - 3 + i * 3.0, sk.dy + 8), Offset(sk.dx - 3 + i * 3.0, sk.dy + 12.5), _s(shade, 1));
    }
    for (final dx in [-3.8, 4.8]) {
      c.drawCircle(sk + Offset(dx, -0.5), 3.1, _f(Colors.black));
      c.drawCircle(sk + Offset(dx + 0.4, -0.5), 1.1, _f(const Color(0xFFFF5252)));
    }
    _poly(c, [sk + const Offset(0.5, 3), sk + const Offset(-1.5, 6), sk + const Offset(2.5, 6)], _f(Colors.black));

    final shoulder = Offset(58 + lunge, 43 + bob);
    if (!archer) {
      final a = _armAngle(p, 0.25);
      final hand = shoulder + Offset(math.cos(a), math.sin(a)) * 17;
      final dir = Offset(math.cos(a), math.sin(a));
      final perp = Offset(-dir.dy, dir.dx);
      c.drawLine(shoulder, hand, _s(bone, 3.6));
      c.drawLine(hand - dir * 3, hand + dir * 26, _s(const Color(0xFFB0BEC5), 3));
      c.drawLine(hand + perp * 4.5, hand - perp * 4.5, _s(const Color(0xFF6D4C41), 2.6));
    } else {
      final pull = 0.35 + 0.65 * (p > 0 && p < 0.5 ? p / 0.5 : 0.0);
      final grip = Offset(76, 44 + bob);
      c.drawLine(shoulder, grip, _s(bone, 3.4));
      final nock = Offset(72 - pull * 9, 44 + bob);
      c.drawLine(Offset(56, 45 + bob), nock, _s(bone, 2.6));
      final bow = Path()
        ..moveTo(72, 22 + bob)
        ..quadraticBezierTo(92, 44 + bob, 72, 66 + bob);
      c.drawPath(bow, _s(const Color(0xFF6D4C41), 3.2));
      c.drawPath(
        Path()
          ..moveTo(72, 22 + bob)
          ..lineTo(nock.dx, nock.dy)
          ..lineTo(72, 66 + bob),
        _s(Colors.white70, 1),
      );
      if (p < 0.5) {
        c.drawLine(nock, Offset(96, 44 + bob), _s(bone, 1.8));
        _poly(c, [Offset(96, 41.5 + bob), Offset(96, 46.5 + bob), Offset(101, 44 + bob)], _f(const Color(0xFFB0BEC5)));
      }
    }
  }

  // ------------------------------------------------------------------
  // PLAYER UNITS (used for the Army / Collection screens when the PNG art
  // for them isn't present, and as an in-battle fallback).
  // ------------------------------------------------------------------
  static void _archer(Canvas c) {
    c.drawLine(const Offset(44, 90), const Offset(41, 68), _s(const Color(0xFF2E5E34), 7)); // legs
    c.drawLine(const Offset(56, 90), const Offset(59, 68), _s(const Color(0xFF2E5E34), 7));
    _poly(c, const [Offset(38, 44), Offset(62, 44), Offset(66, 76), Offset(34, 76)], _f(const Color(0xFF388E3C)));
    c.drawRect(const Rect.fromLTRB(36, 60, 64, 64), _f(const Color(0xFF6D4C41))); // belt
    _poly(c, const [Offset(30, 34), Offset(50, 6), Offset(70, 34)], _f(const Color(0xFF2E7D32))); // hood
    c.drawCircle(const Offset(50, 30), 12, _f(const Color(0xFF2E7D32)));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 33), width: 14, height: 14), _f(const Color(0xFFFFCC99)));
    c.drawCircle(const Offset(47, 32), 1.4, _f(Colors.black));
    c.drawCircle(const Offset(53, 32), 1.4, _f(Colors.black));
    c.drawRect(const Rect.fromLTRB(30, 40, 36, 66), _f(const Color(0xFF6D4C41))); // quiver
    final bow = Path()
      ..moveTo(70, 16)
      ..quadraticBezierTo(96, 50, 70, 84);
    c.drawPath(bow, _s(const Color(0xFF8D6E63), 3.6));
    c.drawLine(const Offset(70, 16), const Offset(70, 84), _s(Colors.white70, 1));
    c.drawLine(const Offset(56, 52), const Offset(72, 50), _s(const Color(0xFFFFCC99), 4));
  }

  static void _knight(Canvas c) {
    c.drawLine(const Offset(43, 92), const Offset(43, 70), _s(const Color(0xFF78909C), 8));
    c.drawLine(const Offset(57, 92), const Offset(57, 70), _s(const Color(0xFF78909C), 8));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(34, 38, 66, 74), const Radius.circular(6)), _f(const Color(0xFF90A4AE)));
    c.drawRect(const Rect.fromLTRB(34, 60, 66, 64), _f(const Color(0xFFE0A82E)));
    c.drawCircle(const Offset(50, 24), 13, _f(const Color(0xFF90A4AE)));
    c.drawRect(const Rect.fromLTRB(40, 22, 60, 27), _f(const Color(0xFF263238)));
    _poly(c, const [Offset(46, 12), Offset(54, 12), Offset(62, 2), Offset(50, 6)], _f(const Color(0xFFC62828))); // plume
    final shield = Path()
      ..moveTo(18, 42)
      ..lineTo(40, 42)
      ..lineTo(40, 62)
      ..quadraticBezierTo(29, 78, 18, 62)
      ..close();
    c.drawPath(shield, _f(const Color(0xFF1565C0)));
    c.drawPath(shield, _s(const Color(0xFFE0A82E), 2));
    c.drawLine(const Offset(72, 66), const Offset(84, 12), _s(const Color(0xFFCFD8DC), 4));
    c.drawLine(const Offset(66, 60), const Offset(80, 60), _s(const Color(0xFFE0A82E), 3.4));
  }

  static void _mage(Canvas c) {
    _poly(c, const [Offset(36, 42), Offset(64, 42), Offset(74, 92), Offset(26, 92)], _f(const Color(0xFF3949AB)));
    c.drawLine(const Offset(38, 62), const Offset(62, 62), _s(const Color(0xFFE0A82E), 3));
    _poly(c, const [Offset(32, 28), Offset(68, 28), Offset(58, 2)], _f(const Color(0xFF5C6BC0)));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 28), width: 40, height: 9), _f(const Color(0xFF3949AB)));
    c.drawCircle(const Offset(52, 16), 2.4, _f(const Color(0xFFFFEB3B)));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 37), width: 16, height: 14), _f(const Color(0xFFFFCC99)));
    _poly(c, const [Offset(42, 40), Offset(58, 40), Offset(50, 56)], _f(Colors.white)); // beard
    c.drawCircle(const Offset(46, 35), 1.3, _f(Colors.black));
    c.drawCircle(const Offset(54, 35), 1.3, _f(Colors.black));
    c.drawLine(const Offset(78, 92), const Offset(78, 28), _s(const Color(0xFF8D6E63), 4));
    c.drawCircle(const Offset(78, 22), 11, _f(const Color(0xFF26C6DA).withValues(alpha: 0.35)));
    c.drawCircle(const Offset(78, 22), 6.5, _f(const Color(0xFF4DD0E1)));
    c.drawCircle(const Offset(76, 20), 2, _f(Colors.white));
    c.drawLine(const Offset(62, 52), const Offset(76, 40), _s(const Color(0xFFFFCC99), 4));
  }

  static void _dragon(Canvas c, double w) {
    final flap = math.sin(w * 1.5) * 4;
    _poly(c, [const Offset(36, 50), Offset(14, 12 + flap), const Offset(44, 30), Offset(56, 6 + flap), const Offset(62, 46)],
        _f(const Color(0xFFB71C1C)));
    final tail = Path()
      ..moveTo(28, 66)
      ..quadraticBezierTo(8, 74, 6, 54);
    c.drawPath(tail, _s(const Color(0xFFD32F2F), 7));
    c.drawOval(Rect.fromCenter(center: const Offset(46, 62), width: 54, height: 36), _f(const Color(0xFFD32F2F)));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 70), width: 34, height: 16), _f(const Color(0xFFFFCC80)));
    c.drawLine(const Offset(38, 76), const Offset(38, 92), _s(const Color(0xFFB71C1C), 6));
    c.drawLine(const Offset(58, 76), const Offset(58, 92), _s(const Color(0xFFB71C1C), 6));
    c.drawLine(const Offset(62, 54), const Offset(74, 38), _s(const Color(0xFFD32F2F), 10)); // neck
    c.drawCircle(const Offset(76, 34), 12, _f(const Color(0xFFD32F2F)));
    _poly(c, const [Offset(82, 30), Offset(98, 36), Offset(82, 44)], _f(const Color(0xFFD32F2F)));
    _poly(c, const [Offset(70, 24), Offset(68, 10), Offset(76, 22)], _f(const Color(0xFFFFF3D6)));
    c.drawCircle(const Offset(78, 30), 2.6, _f(const Color(0xFFFFEB3B)));
    _teeth(c, const Offset(84, 43), const Offset(96, 39), 3, 3, const Offset(0, -1), _f(_tooth));
    c.drawCircle(const Offset(100, 38), 4, _f(const Color(0xFFFF9800).withValues(alpha: 0.8)));
  }

  static void _panda(Canvas c) {
    c.drawLine(const Offset(42, 92), const Offset(42, 74), _s(Colors.black87, 10));
    c.drawLine(const Offset(58, 92), const Offset(58, 74), _s(Colors.black87, 10));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 62), width: 46, height: 46), _f(Colors.white));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(36, 50, 64, 76), const Radius.circular(6)), _f(const Color(0xFF78909C)));
    c.drawRect(const Rect.fromLTRB(36, 60, 64, 63), _f(const Color(0xFFE0A82E)));
    c.drawLine(const Offset(34, 52), const Offset(24, 70), _s(Colors.black87, 9));
    c.drawLine(const Offset(66, 52), const Offset(78, 44), _s(Colors.black87, 9));
    c.drawCircle(const Offset(36, 22), 7, _f(Colors.black87));
    c.drawCircle(const Offset(64, 22), 7, _f(Colors.black87));
    c.drawCircle(const Offset(50, 34), 17, _f(Colors.white));
    c.drawOval(Rect.fromCenter(center: const Offset(43, 33), width: 9, height: 12), _f(Colors.black87));
    c.drawOval(Rect.fromCenter(center: const Offset(57, 33), width: 9, height: 12), _f(Colors.black87));
    c.drawCircle(const Offset(43.5, 32), 1.6, _f(Colors.white));
    c.drawCircle(const Offset(56.5, 32), 1.6, _f(Colors.white));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 40), width: 7, height: 5), _f(Colors.black87));
  }
}

/// CustomPainter wrapper so widgets can show a creature with a plain
/// CustomPaint (used by SpriteThumb when there is no PNG to show).
class CreatureThumbPainter extends CustomPainter {
  final CreatureKind kind;
  final bool facingLeft;
  const CreatureThumbPainter(this.kind, {this.facingLeft = false});

  @override
  void paint(Canvas canvas, Size size) {
    CreaturePainter.paint(canvas, size, kind, walk: 0.6, facingLeft: facingLeft);
  }

  @override
  bool shouldRepaint(CreatureThumbPainter old) => old.kind != kind || old.facingLeft != facingLeft;
}
