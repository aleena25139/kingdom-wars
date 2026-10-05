// Second half of the Town art (same library as town_art.dart, so it can use its
// private helpers): water, rails, trains, bridges, LEGO, extra houses,
// buildings and parks, plus the endless greenery that grows by itself on
// every empty tile.
part of 'town_art.dart';

class TownArtX {
  TownArtX._();

  // ---- tiny aliases for the private helpers in TownArt ----
  static Paint _f(Color c) => TownArt._fill(c);
  static Paint _st(Color c, double w) => TownArt._stroke(c, w);
  static Color _sh(Color c, double a) => TownArt._shade(c, a);
  static int _h(int a, int b) => TownArt._hash(a, b);

  static const int _n = TownArt.north, _e = TownArt.east, _s = TownArt.south, _w = TownArt.west;

  // ------------------------------------------------------------------
  // Master switch for every piece that is not in TownArt.draw
  // ------------------------------------------------------------------
  static void draw(Canvas c, String id, Rect r, double t, {int col = 0, int row = 0, int mask = 0}) {
    switch (id) {
      // houses
      case 'bungalow':
        return _bungalow(c, r, t);
      case 'townhouse':
        return _townhouse(c, r, t);
      case 'tower_block':
        return _towerBlock(c, r, t);
      // buildings
      case 'cafe':
        return _cafe(c, r, t);
      case 'gas_station':
        return _gasStation(c, r, t);
      case 'post_office':
        return _postOffice(c, r, t);
      case 'police':
        return _police(c, r, t);
      case 'cinema':
        return _cinema(c, r, t);
      case 'hotel':
        return _hotel(c, r, t);
      // parks
      case 'basketball':
        return _basketball(c, r, t);
      case 'pool':
        return _pool(c, r, t);
      case 'carousel':
        return _carousel(c, r, t);
      case 'ferris_wheel':
        return _ferrisWheel(c, r, t);
      // water pieces (the water itself is drawn by drawWater underneath)
      case 'bridge':
        return _bridge(c, r, mask, stone: false);
      case 'stone_bridge':
        return _bridge(c, r, mask, stone: true);
      case 'boat':
        return _boat(c, r, t, col + row);
      // trains
      case 'train_stop':
        return _trainStop(c, r, t);
      case 'station':
        return _station(c, r, t);
      case 'signal':
        return _signal(c, r, t);
      case 'train':
        return _train(c, r, t, mask, loco: true);
      case 'train_wagon':
        return _train(c, r, t, mask, loco: false, seed: col + row);
      // lego
      case 'lego_plate':
        return _legoPlate(c, r);
      case 'lego_brick_red':
        return _legoSingle(c, r, const Color(0xFFD32F2F));
      case 'lego_brick_blue':
        return _legoSingle(c, r, const Color(0xFF1976D2));
      case 'lego_brick_yellow':
        return _legoSingle(c, r, const Color(0xFFFBC02D));
      case 'lego_brick_green':
        return _legoSingle(c, r, const Color(0xFF388E3C));
      case 'lego_tree':
        return _legoTree(c, r);
      case 'lego_figure':
        return _legoFigure(c, r, t);
      case 'lego_car':
        return _legoCar(c, r, t);
      case 'lego_house':
        return _legoHouse(c, r);
      case 'lego_tower':
        return _legoTower(c, r);
      case 'lego_castle':
        return _legoCastle(c, r, t);
      // nature / decor
      case 'bush':
        return _bush(c, r, col + row);
      case 'rock':
        return _rock(c, r, col, row);
      case 'bus_stop':
        return _busStop(c, r);
      case 'car':
        return _car(c, r);
      case 'bus':
        return _bus(c, r);
    }
  }

  // ==================================================================
  // ENDLESS GREENERY: every empty tile may grow trees, pines, bushes,
  // rocks or wild flowers. The same (col,row) always grows the same thing.
  // ==================================================================
  static const int ambNone = 0, ambTree = 1, ambPine = 2, ambBush = 3, ambRock = 4, ambFlowers = 5, ambGrass = 6;

  static int ambient(int col, int row) {
    final d2 = col * col + row * row;
    final patch = (_h((col / 7).floor(), (row / 7).floor() + 977) % 100) / 100.0;
    double density;
    if (patch > 0.62) {
      density = 0.58; // dense forest
    } else if (patch < 0.14) {
      density = 0.04; // open meadow
    } else {
      density = 0.17;
    }
    // keep the very start of the town fairly open so building is easy
    if (d2 < 49) density *= 0.2;
    final a = _h(col, row * 31 + 7);
    if ((a % 1000) / 1000.0 < density) {
      final k = (a ~/ 1000) % 12;
      if (k < 4) return ambTree;
      if (k < 8) return ambPine;
      if (k < 11) return ambBush;
      return ambRock;
    }
    final b = _h(row, col * 17 + 3);
    final fl = b % 100;
    if (fl < 11) return ambFlowers;
    if (fl < 24) return ambGrass;
    return ambNone;
  }

  /// Flat greenery (flowers and long grass) - drawn with the ground.
  static void drawAmbientFlat(Canvas c, int kind, Rect r, int col, int row, double t) {
    final s = r.width;
    if (kind == ambFlowers) {
      final cols = [const Color(0xFFE91E63), const Color(0xFFFFEB3B), const Color(0xFFFFFFFF), const Color(0xFFAB47BC), const Color(0xFFFF7043)];
      final h = _h(col, row);
      for (var i = 0; i < 5; i++) {
        final k = _h(h, i + 40);
        final x = r.left + (k % 100) / 100 * s * 0.8 + s * 0.1;
        final y = r.top + ((k ~/ 100) % 100) / 100 * s * 0.7 + s * 0.2;
        final sway = math.sin(t * 2 + i + col) * 0.8;
        c.drawLine(Offset(x, y + s * 0.07), Offset(x + sway, y), _st(const Color(0xFF2E7D32), 1.0));
        c.drawCircle(Offset(x + sway, y), s * 0.035, _f(cols[(h + i) % cols.length]));
        c.drawCircle(Offset(x + sway, y), s * 0.012, _f(const Color(0xFFFFC107)));
      }
    } else if (kind == ambGrass) {
      final h = _h(col, row);
      final blade = _st(const Color(0xFF3F8C2E), math.max(1.0, s * 0.035));
      for (var i = 0; i < 6; i++) {
        final k = _h(h, i + 60);
        final x = r.left + (k % 100) / 100 * s * 0.84 + s * 0.08;
        final y = r.top + ((k ~/ 100) % 100) / 100 * s * 0.7 + s * 0.22;
        final sway = math.sin(t * 1.6 + i + col * 0.5) * s * 0.02;
        c.drawLine(Offset(x, y), Offset(x - s * 0.04 + sway, y - s * 0.13), blade);
        c.drawLine(Offset(x, y), Offset(x + sway, y - s * 0.17), blade);
        c.drawLine(Offset(x, y), Offset(x + s * 0.04 + sway, y - s * 0.12), blade);
      }
    }
  }

  /// Standing greenery (trees, pines, bushes, rocks) - drawn with the buildings.
  static void drawAmbientTall(Canvas c, int kind, Rect r, double t, int col, int row) {
    // nudge each one a little so forests do not look like a grid
    final j = _h(col + 5, row + 11);
    final shifted = r.translate(((j % 21) - 10) / 10 * r.width * 0.08, ((j ~/ 21) % 11 - 5) / 5 * r.width * 0.04);
    switch (kind) {
      case ambTree:
        return TownArt._tree(c, shifted, t, col + row);
      case ambPine:
        return TownArt._pine(c, shifted, t);
      case ambBush:
        return _bush(c, shifted, col + row);
      case ambRock:
        return _rock(c, shifted, col, row);
    }
  }

  // ==================================================================
  // WATER
  // ==================================================================
  static void drawWater(Canvas c, String id, Rect r, int mask, double t, int col, int row) {
    final s = r.width;
    final cx = r.center.dx, cy = r.center.dy;
    const sand = Color(0xFFDCC98F);
    const deep = Color(0xFF2F8FD8);
    const light = Color(0xFF5DB4F0);

    if (id == 'lake') {
      final blob = Rect.fromLTWH(r.left + s * 0.03, r.top + s * 0.06, s * 0.94, s * 0.88);
      c.drawOval(blob.inflate(s * 0.04), _f(sand));
      c.drawOval(blob, _f(deep));
      c.drawOval(blob.deflate(s * 0.1), _f(light.withOpacity(0.5)));
      for (var i = 0; i < 3; i++) {
        final k = ((t * 0.18) + i / 3 + col * 0.13) % 1.0;
        final rr = s * (0.08 + 0.28 * k);
        c.drawCircle(
          Offset(cx + math.sin(i * 2.1 + col) * s * 0.18, cy + math.cos(i * 1.7 + row) * s * 0.14),
          rr,
          _st(Colors.white.withOpacity(0.5 * (1 - k)), 1.2),
        );
      }
      // reeds
      final reed = _st(const Color(0xFF4F8F3A), math.max(1.0, s * 0.03));
      for (var i = 0; i < 3; i++) {
        final x = r.left + s * (0.12 + i * 0.05);
        final y = r.bottom - s * 0.2;
        c.drawLine(Offset(x, y), Offset(x - s * 0.02, y - s * 0.16), reed);
        c.drawOval(Rect.fromCenter(center: Offset(x - s * 0.02, y - s * 0.18), width: s * 0.04, height: s * 0.08), _f(const Color(0xFF6D4C41)));
      }
      return;
    }

    final wd = s * 0.72;
    Rect arm(int bit) {
      switch (bit) {
        case _n:
          return Rect.fromLTRB(cx - wd / 2, r.top, cx + wd / 2, cy);
        case _s:
          return Rect.fromLTRB(cx - wd / 2, cy, cx + wd / 2, r.bottom);
        case _e:
          return Rect.fromLTRB(cx, cy - wd / 2, r.right, cy + wd / 2);
        default:
          return Rect.fromLTRB(r.left, cy - wd / 2, cx, cy + wd / 2);
      }
    }

    var m = mask;
    if (m == 0) m = _e | _w;
    final parts = <Rect>[Rect.fromCenter(center: r.center, width: wd, height: wd)];
    for (final b in [_n, _e, _s, _w]) {
      if (m & b != 0) parts.add(arm(b));
    }
    for (final p in parts) {
      c.drawRect(p.inflate(s * 0.045), _f(sand));
    }
    for (final p in parts) {
      c.drawRect(p, _f(deep));
    }
    for (final p in parts) {
      c.drawRect(p.deflate(s * 0.12), _f(light.withOpacity(0.35)));
    }
    final horiz = m & (_e | _w) != 0;
    final vert = m & (_n | _s) != 0;
    final ripple = _st(Colors.white.withOpacity(0.55), math.max(1.0, s * 0.025));
    for (var i = 0; i < 3; i++) {
      final ph = (t * 0.12 + i / 3 + col * 0.21 + row * 0.11) % 1.0;
      final off = (i - 1) * s * 0.2;
      if (horiz) {
        final x = r.left + ph * s;
        c.drawLine(Offset(x, cy + off), Offset(math.min(x + s * 0.16, r.right), cy + off), ripple);
      }
      if (vert) {
        final y = r.top + ph * s;
        c.drawLine(Offset(cx + off, y), Offset(cx + off, math.min(y + s * 0.16, r.bottom)), ripple);
      }
    }
  }

  // ==================================================================
  // RAILS
  // ==================================================================
  static void drawRail(Canvas c, Rect r, int mask, int col, int row) {
    final s = r.width;
    final cx = r.center.dx, cy = r.center.dy;
    var m = mask;
    if (m == 0) m = _e | _w;
    final bedW = s * 0.5;
    final bed = _f(const Color(0xFF8D857A));
    final sleeper = _st(const Color(0xFF5B4630), math.max(1.5, s * 0.045));
    final rail = _st(const Color(0xFFCFD3D8), math.max(1.2, s * 0.03));
    final railDark = _st(const Color(0xFF5E6268), math.max(1.2, s * 0.05));

    void armH(double x0, double x1) {
      c.drawRect(Rect.fromLTRB(x0, cy - bedW / 2, x1, cy + bedW / 2), bed);
      for (var x = x0 + s * 0.04; x < x1; x += s * 0.12) {
        c.drawLine(Offset(x, cy - bedW * 0.46), Offset(x, cy + bedW * 0.46), sleeper);
      }
      for (final dy in [-s * 0.1, s * 0.1]) {
        c.drawLine(Offset(x0, cy + dy + 1), Offset(x1, cy + dy + 1), railDark);
        c.drawLine(Offset(x0, cy + dy), Offset(x1, cy + dy), rail);
      }
    }

    void armV(double y0, double y1) {
      c.drawRect(Rect.fromLTRB(cx - bedW / 2, y0, cx + bedW / 2, y1), bed);
      for (var y = y0 + s * 0.04; y < y1; y += s * 0.12) {
        c.drawLine(Offset(cx - bedW * 0.46, y), Offset(cx + bedW * 0.46, y), sleeper);
      }
      for (final dx in [-s * 0.1, s * 0.1]) {
        c.drawLine(Offset(cx + dx + 1, y0), Offset(cx + dx + 1, y1), railDark);
        c.drawLine(Offset(cx + dx, y0), Offset(cx + dx, y1), rail);
      }
    }

    // centre block so corners look joined
    c.drawRect(Rect.fromCenter(center: r.center, width: bedW, height: bedW), bed);
    if (m & _e != 0) armH(cx, r.right);
    if (m & _w != 0) armH(r.left, cx);
    if (m & _n != 0) armV(r.top, cy);
    if (m & _s != 0) armV(cy, r.bottom);
  }

  // ------------------------------------------------------------------
  // Bridges (flat, drawn over the water)
  // ------------------------------------------------------------------
  static void _bridge(Canvas c, Rect r, int mask, {required bool stone}) {
    final s = r.width;
    final cx = r.center.dx, cy = r.center.dy;
    final waterFlowsSideways = (mask & (_e | _w) != 0 && mask & (_n | _s) == 0) || mask == 0;
    // water runs left-right -> the bridge crosses top-to-bottom
    final vertical = waterFlowsSideways;
    final deck = vertical
        ? Rect.fromLTRB(cx - s * 0.25, r.top - s * 0.02, cx + s * 0.25, r.bottom + s * 0.02)
        : Rect.fromLTRB(r.left - s * 0.02, cy - s * 0.25, r.right + s * 0.02, cy + s * 0.25);
    final base = stone ? const Color(0xFFA7A39A) : const Color(0xFFB8803F);
    final edge = stone ? const Color(0xFF6F6B63) : const Color(0xFF6B4423);
    c.drawRect(deck.inflate(s * 0.03), _f(Colors.black.withOpacity(0.2)));
    c.drawRect(deck, _f(base));
    final line = _st(edge.withOpacity(0.7), 1.0);
    if (vertical) {
      for (var y = deck.top + s * 0.08; y < deck.bottom; y += s * 0.11) {
        c.drawLine(Offset(deck.left, y), Offset(deck.right, y), line);
      }
    } else {
      for (var x = deck.left + s * 0.08; x < deck.right; x += s * 0.11) {
        c.drawLine(Offset(x, deck.top), Offset(x, deck.bottom), line);
      }
    }
    // side rails + posts
    final railPaint = _st(stone ? const Color(0xFFCFCABF) : const Color(0xFF8A5A2B), math.max(2.0, s * 0.06));
    final post = _f(edge);
    if (vertical) {
      c.drawLine(Offset(deck.left, deck.top), Offset(deck.left, deck.bottom), railPaint);
      c.drawLine(Offset(deck.right, deck.top), Offset(deck.right, deck.bottom), railPaint);
      for (var k = 0; k <= 3; k++) {
        final y = deck.top + deck.height * k / 3;
        c.drawRect(Rect.fromCenter(center: Offset(deck.left, y), width: s * 0.07, height: s * 0.07), post);
        c.drawRect(Rect.fromCenter(center: Offset(deck.right, y), width: s * 0.07, height: s * 0.07), post);
      }
    } else {
      c.drawLine(Offset(deck.left, deck.top), Offset(deck.right, deck.top), railPaint);
      c.drawLine(Offset(deck.left, deck.bottom), Offset(deck.right, deck.bottom), railPaint);
      for (var k = 0; k <= 3; k++) {
        final x = deck.left + deck.width * k / 3;
        c.drawRect(Rect.fromCenter(center: Offset(x, deck.top), width: s * 0.07, height: s * 0.07), post);
        c.drawRect(Rect.fromCenter(center: Offset(x, deck.bottom), width: s * 0.07, height: s * 0.07), post);
      }
    }
    if (stone) {
      // a crown stone in the middle
      c.drawCircle(Offset(cx, cy), s * 0.07, _f(const Color(0xFFD8D3C7)));
      c.drawCircle(Offset(cx, cy), s * 0.07, _st(edge, 1.0));
    }
  }

  static void _boat(Canvas c, Rect r, double t, int seed) {
    final s = r.width;
    final bob = math.sin(t * 1.8 + seed) * s * 0.02;
    final tilt = math.sin(t * 1.3 + seed) * 0.05;
    c.save();
    c.translate(r.center.dx, r.center.dy + bob);
    c.rotate(tilt);
    final hull = Path()
      ..moveTo(-s * 0.26, 0)
      ..lineTo(s * 0.26, 0)
      ..lineTo(s * 0.17, s * 0.12)
      ..lineTo(-s * 0.17, s * 0.12)
      ..close();
    c.drawPath(hull, _f(const Color(0xFF8D4B2A)));
    c.drawPath(hull, _st(const Color(0xFF4E2A14), 1.2));
    c.drawLine(Offset(0, 0), Offset(0, -s * 0.38), _st(const Color(0xFF4E2A14), math.max(1.2, s * 0.03)));
    final sail = Path()
      ..moveTo(s * 0.02, -s * 0.36)
      ..lineTo(s * 0.22, -s * 0.04)
      ..lineTo(s * 0.02, -s * 0.04)
      ..close();
    c.drawPath(sail, _f(Colors.white));
    c.drawPath(sail, _st(const Color(0xFFBBBBBB), 0.8));
    final sail2 = Path()
      ..moveTo(-s * 0.02, -s * 0.3)
      ..lineTo(-s * 0.16, -s * 0.04)
      ..lineTo(-s * 0.02, -s * 0.04)
      ..close();
    c.drawPath(sail2, _f(const Color(0xFFE53935)));
    c.restore();
  }

  // ==================================================================
  // TRAINS
  // ==================================================================
  static void _train(Canvas c, Rect r, double t, int mask, {required bool loco, int seed = 0}) {
    final s = r.width;
    final vertical = (mask & (_n | _s) != 0) && (mask & (_e | _w) == 0);
    final chug = math.sin(t * 2.4 + seed) * s * 0.012;
    c.save();
    c.translate(r.center.dx, r.center.dy);
    if (vertical) c.rotate(math.pi / 2);
    // everything below is drawn for a horizontal track, centre = (0,0)
    c.drawOval(Rect.fromCenter(center: Offset(0, s * 0.2), width: s * 0.9, height: s * 0.14), _f(Colors.black.withOpacity(0.2)));
    final wheelY = s * 0.15;
    if (loco) {
      final black = const Color(0xFF2E2E36);
      // boiler
      final boiler = RRect.fromRectAndRadius(Rect.fromLTWH(-s * 0.4, -s * 0.12 + chug, s * 0.52, s * 0.22), Radius.circular(s * 0.1));
      c.drawRRect(boiler, _f(black));
      c.drawRRect(boiler, _st(Colors.black, 1.0));
      c.drawRect(Rect.fromLTWH(-s * 0.4, s * 0.06 + chug, s * 0.52, s * 0.05), _f(const Color(0xFFC62828)));
      // chimney
      final chim = Rect.fromLTWH(-s * 0.34, -s * 0.28 + chug, s * 0.1, s * 0.17);
      c.drawRect(chim, _f(const Color(0xFF444450)));
      c.drawRect(Rect.fromLTWH(-s * 0.37, -s * 0.31 + chug, s * 0.16, s * 0.05), _f(const Color(0xFF222228)));
      // steam
      TownArt._smoke(c, Offset(-s * 0.29, -s * 0.31 + chug), t, s);
      // dome
      c.drawArc(Rect.fromLTWH(-s * 0.16, -s * 0.2 + chug, s * 0.14, s * 0.16), math.pi, math.pi, true, _f(const Color(0xFFC9A24B)));
      // cab
      final cab = Rect.fromLTWH(s * 0.1, -s * 0.24 + chug, s * 0.3, s * 0.34);
      c.drawRect(cab, _f(const Color(0xFFC62828)));
      c.drawRect(cab, _st(const Color(0xFF7F1717), 1.0));
      c.drawRect(Rect.fromLTWH(s * 0.07, -s * 0.28 + chug, s * 0.36, s * 0.05), _f(const Color(0xFF3B2A1A)));
      c.drawRect(Rect.fromLTWH(s * 0.17, -s * 0.16 + chug, s * 0.16, s * 0.14), _f(const Color(0xFF9AD7F5)));
      // headlamp
      c.drawCircle(Offset(-s * 0.4, -s * 0.02 + chug), s * 0.035, _f(const Color(0xFFFFE08A)));
    } else {
      final colors = [const Color(0xFF1E88E5), const Color(0xFF43A047), const Color(0xFFFB8C00), const Color(0xFF8E24AA)];
      final body = Rect.fromLTWH(-s * 0.42, -s * 0.2 + chug, s * 0.84, s * 0.3);
      final col = colors[seed.abs() % colors.length];
      c.drawRect(body, _f(col));
      c.drawRect(body, _st(_sh(col, -0.3), 1.0));
      for (var i = 1; i < 5; i++) {
        final x = body.left + body.width * i / 5;
        c.drawLine(Offset(x, body.top), Offset(x, body.bottom), _st(_sh(col, -0.15), 0.8));
      }
      c.drawRect(Rect.fromLTWH(body.left, body.top - s * 0.04, body.width, s * 0.04), _f(const Color(0xFF444450)));
      c.drawRect(Rect.fromLTWH(-s * 0.08, -s * 0.1 + chug, s * 0.16, s * 0.18), _f(Colors.black.withOpacity(0.25)));
    }
    // wheels
    final wheelCount = loco ? 4 : 3;
    for (var i = 0; i < wheelCount; i++) {
      final x = -s * 0.32 + i * (loco ? s * 0.21 : s * 0.32);
      c.drawCircle(Offset(x, wheelY), s * 0.07, _f(const Color(0xFF1B1B1F)));
      c.drawCircle(Offset(x, wheelY), s * 0.07, _st(const Color(0xFFB0B4BA), 1.0));
      final a = t * 3 + i;
      c.drawLine(Offset(x, wheelY), Offset(x + math.cos(a) * s * 0.05, wheelY + math.sin(a) * s * 0.05), _st(const Color(0xFFB0B4BA), 1.0));
    }
    c.restore();
  }

  static void _trackStrip(Canvas c, Rect r, double y) {
    // a short horizontal track along the bottom of the tile (used by station / stop)
    final s = r.width;
    c.drawRect(Rect.fromLTRB(r.left, y - s * 0.07, r.right, y + s * 0.07), _f(const Color(0xFF8D857A)));
    for (var x = r.left + s * 0.04; x < r.right; x += s * 0.12) {
      c.drawLine(Offset(x, y - s * 0.06), Offset(x, y + s * 0.06), _st(const Color(0xFF5B4630), math.max(1.5, s * 0.04)));
    }
    c.drawLine(Offset(r.left, y - s * 0.035), Offset(r.right, y - s * 0.035), _st(const Color(0xFFCFD3D8), math.max(1.0, s * 0.028)));
    c.drawLine(Offset(r.left, y + s * 0.035), Offset(r.right, y + s * 0.035), _st(const Color(0xFFCFD3D8), math.max(1.0, s * 0.028)));
  }

  static void _trainStop(Canvas c, Rect r, double t) {
    final s = r.width;
    _trackStrip(c, r, r.bottom - s * 0.1);
    // platform
    final plat = Rect.fromLTRB(r.left + s * 0.04, r.bottom - s * 0.36, r.right - s * 0.04, r.bottom - s * 0.2);
    c.drawRect(plat, _f(const Color(0xFFC9C3B6)));
    c.drawRect(plat, _st(const Color(0xFF8E887B), 1.0));
    c.drawRect(Rect.fromLTWH(plat.left, plat.bottom - s * 0.025, plat.width, s * 0.025), _f(const Color(0xFFFBC02D)));
    // shelter
    final posts = _st(const Color(0xFF5E6268), math.max(1.5, s * 0.04));
    c.drawLine(Offset(plat.left + s * 0.1, plat.top), Offset(plat.left + s * 0.1, plat.top - s * 0.3), posts);
    c.drawLine(Offset(plat.right - s * 0.1, plat.top), Offset(plat.right - s * 0.1, plat.top - s * 0.3), posts);
    final roof = Rect.fromLTRB(plat.left + s * 0.02, plat.top - s * 0.38, plat.right - s * 0.02, plat.top - s * 0.28);
    c.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(s * 0.03)), _f(const Color(0xFFE53935)));
    c.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(s * 0.03)), _st(const Color(0xFF8E1B18), 1.0));
    // bench + sign
    c.drawRect(Rect.fromLTWH(plat.center.dx - s * 0.12, plat.top - s * 0.09, s * 0.24, s * 0.04), _f(const Color(0xFF8A5A2B)));
    c.drawCircle(Offset(plat.right - s * 0.1, plat.top - s * 0.2), s * 0.05, _f(Colors.white));
    c.drawCircle(Offset(plat.right - s * 0.1, plat.top - s * 0.2), s * 0.05, _st(const Color(0xFF1976D2), 1.5));
  }

  static void _station(Canvas c, Rect r, double t) {
    final s = r.width;
    _trackStrip(c, r, r.bottom - s * 0.1);
    final plat = Rect.fromLTRB(r.left, r.bottom - s * 0.3, r.right, r.bottom - s * 0.2);
    c.drawRect(plat, _f(const Color(0xFFC9C3B6)));
    c.drawRect(Rect.fromLTWH(plat.left, plat.bottom - s * 0.025, plat.width, s * 0.025), _f(const Color(0xFFFBC02D)));
    // main hall
    final hall = Rect.fromLTRB(r.left + s * 0.05, plat.top - s * 0.52, r.right - s * 0.05, plat.top);
    TownArt._wall(c, hall, const Color(0xFFF1E6CB));
    TownArt._gable(c, hall, const Color(0xFF9C2B2B), s * 0.28, overhang: 0.05);
    // tall clock gable
    final clockBox = Rect.fromCenter(center: Offset(hall.center.dx, hall.top - s * 0.18), width: s * 0.34, height: s * 0.3);
    c.drawRect(clockBox, _f(const Color(0xFFE6D9B8)));
    c.drawRect(clockBox, _st(const Color(0xFF8A7A52), 1.2));
    final cc = clockBox.center;
    c.drawCircle(cc, s * 0.1, _f(Colors.white));
    c.drawCircle(cc, s * 0.1, _st(const Color(0xFF3B2A1A), 1.5));
    final a = t * 0.3;
    c.drawLine(cc, cc.translate(math.sin(a) * s * 0.07, -math.cos(a) * s * 0.07), _st(const Color(0xFF3B2A1A), 1.4));
    c.drawLine(cc, cc.translate(math.sin(a * 12) * s * 0.09, -math.cos(a * 12) * s * 0.09), _st(const Color(0xFF3B2A1A), 1.0));
    final roofTop = Path()
      ..moveTo(clockBox.left - s * 0.02, clockBox.top)
      ..lineTo(clockBox.center.dx, clockBox.top - s * 0.14)
      ..lineTo(clockBox.right + s * 0.02, clockBox.top)
      ..close();
    c.drawPath(roofTop, _f(const Color(0xFF7A1F1F)));
    // doors and windows
    TownArt._door(c, Rect.fromLTWH(hall.center.dx - s * 0.08, hall.bottom - s * 0.24, s * 0.16, s * 0.24), color: const Color(0xFF4E342E));
    TownArt._window(c, Rect.fromLTWH(hall.left + s * 0.1, hall.top + s * 0.1, s * 0.14, s * 0.2), lit: true);
    TownArt._window(c, Rect.fromLTWH(hall.right - s * 0.24, hall.top + s * 0.1, s * 0.14, s * 0.2), lit: true);
    TownArt._window(c, Rect.fromLTWH(hall.left + s * 0.1, hall.top + s * 0.34, s * 0.14, s * 0.12));
    TownArt._window(c, Rect.fromLTWH(hall.right - s * 0.24, hall.top + s * 0.34, s * 0.14, s * 0.12));
    // canopy on the platform
    c.drawRect(Rect.fromLTWH(r.left, plat.top - s * 0.04, s * 0.06, s * 0.04), _f(const Color(0xFF5E6268)));
  }

  static void _signal(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.4);
    final x = r.center.dx;
    c.drawLine(Offset(x, r.bottom - s * 0.1), Offset(x, r.bottom - s * 0.6), _st(const Color(0xFF4A4A52), math.max(2.0, s * 0.06)));
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(x - s * 0.1, r.bottom - s * 0.78, s * 0.2, s * 0.3), Radius.circular(s * 0.04));
    c.drawRRect(box, _f(const Color(0xFF26262C)));
    final green = math.sin(t * 0.8) > 0;
    c.drawCircle(Offset(x, r.bottom - s * 0.7), s * 0.055, _f(green ? const Color(0xFF3A1010) : const Color(0xFFFF3B30)));
    c.drawCircle(Offset(x, r.bottom - s * 0.56), s * 0.055, _f(green ? const Color(0xFF34C759) : const Color(0xFF0F3A18)));
  }

  // ==================================================================
  // EXTRA HOUSES (free)
  // ==================================================================
  static void _bungalow(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.92);
    final box = Rect.fromLTWH(r.left + s * 0.06, r.bottom - s * 0.46, s * 0.88, s * 0.34);
    TownArt._wall(c, box, const Color(0xFFB7E0F2));
    TownArt._tiledRoof(c, Rect.fromLTRB(box.left - s * 0.02, box.top, box.right + s * 0.02, box.top + 2), const Color(0xFFB05A3A), s * 0.2, overhang: 0.04);
    final chim = Rect.fromLTWH(box.right - s * 0.22, box.top - s * 0.3, s * 0.09, s * 0.2);
    TownArt._stoneChimney(c, chim);
    TownArt._smoke(c, chim.topCenter, t, s);
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.22, s * 0.14, s * 0.22), color: const Color(0xFFD84315));
    TownArt._window(c, Rect.fromLTWH(box.left + s * 0.1, box.top + s * 0.08, s * 0.16, s * 0.14));
    TownArt._window(c, Rect.fromLTWH(box.right - s * 0.26, box.top + s * 0.08, s * 0.16, s * 0.14));
    // porch
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.2, box.bottom - s * 0.06, s * 0.4, s * 0.06), _f(const Color(0xFF9E8F73)));
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.18, box.bottom - s * 0.3, s * 0.03, s * 0.24), _f(const Color(0xFFFFFFFF)));
    c.drawRect(Rect.fromLTWH(box.center.dx + s * 0.15, box.bottom - s * 0.3, s * 0.03, s * 0.24), _f(const Color(0xFFFFFFFF)));
    // flower pots
    c.drawCircle(Offset(box.left + s * 0.06, box.bottom - s * 0.03), s * 0.03, _f(const Color(0xFFE91E63)));
    c.drawCircle(Offset(box.right - s * 0.06, box.bottom - s * 0.03), s * 0.03, _f(const Color(0xFFFFEB3B)));
  }

  static void _townhouse(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.7);
    final box = Rect.fromLTWH(r.left + s * 0.2, r.bottom - s * 0.98, s * 0.6, s * 0.86);
    TownArt._wall(c, box, const Color(0xFFF4B6C2));
    // stripe between floors
    for (var i = 1; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(box.left, box.top + box.height * i / 3 - 1, box.width, 2), _f(const Color(0xFFFFFFFF).withOpacity(0.7)));
    }
    TownArt._tiledRoof(c, box, const Color(0xFF6D4C41), s * 0.26, overhang: 0.05);
    for (var f = 0; f < 2; f++) {
      TownArt._window(c, Rect.fromLTWH(box.left + s * 0.08, box.top + s * 0.06 + f * s * 0.27, s * 0.14, s * 0.17), lit: f == 1);
      TownArt._window(c, Rect.fromLTWH(box.right - s * 0.22, box.top + s * 0.06 + f * s * 0.27, s * 0.14, s * 0.17));
    }
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.25, s * 0.14, s * 0.25), color: const Color(0xFF4A148C));
    // balcony
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.12, box.top + s * 0.4, s * 0.24, s * 0.03), _f(const Color(0xFF3B2A1A)));
    final chim = Rect.fromLTWH(box.left + s * 0.04, box.top - s * 0.36, s * 0.09, s * 0.22);
    TownArt._stoneChimney(c, chim);
    TownArt._smoke(c, chim.topCenter, t, s);
  }

  static void _towerBlock(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.9);
    final box = Rect.fromLTWH(r.left + s * 0.12, r.bottom - s * 1.55, s * 0.76, s * 1.43);
    TownArt._wall(c, box, const Color(0xFFB9C6D3));
    c.drawRect(Rect.fromLTWH(box.left, box.top, box.width, s * 0.06), _f(const Color(0xFF6C7A89)));
    TownArt._windowGrid(c, Rect.fromLTWH(box.left + s * 0.04, box.top + s * 0.1, box.width - s * 0.08, box.height - s * 0.4), 7, 4, litAlt: true);
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.09, box.bottom - s * 0.22, s * 0.18, s * 0.22), color: const Color(0xFF37474F));
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.2, box.bottom - s * 0.26, s * 0.4, s * 0.04), _f(const Color(0xFF455A64)));
    // roof stuff
    c.drawRect(Rect.fromLTWH(box.left + s * 0.1, box.top - s * 0.1, s * 0.18, s * 0.1), _f(const Color(0xFF78909C)));
    final ax = box.right - s * 0.14;
    c.drawLine(Offset(ax, box.top), Offset(ax, box.top - s * 0.3), _st(const Color(0xFF455A64), 1.5));
    final blink = math.sin(t * 3) > 0;
    c.drawCircle(Offset(ax, box.top - s * 0.3), s * 0.025, _f(blink ? const Color(0xFFFF3B30) : const Color(0xFF5A1612)));
  }

  // ==================================================================
  // EXTRA PUBLIC BUILDINGS
  // ==================================================================
  static void _cafe(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.64, s * 0.8, s * 0.52);
    TownArt._wall(c, box, const Color(0xFFD9F0DA));
    TownArt._gable(c, box, const Color(0xFF2E7D6B), s * 0.2);
    TownArt._stripedAwning(c, Rect.fromLTWH(box.left + s * 0.04, box.top + s * 0.17, box.width - s * 0.08, s * 0.1), const Color(0xFF2E7D6B), Colors.white, 6);
    TownArt._window(c, Rect.fromLTWH(box.left + s * 0.08, box.top + s * 0.31, s * 0.26, s * 0.14), lit: true);
    TownArt._door(c, Rect.fromLTWH(box.right - s * 0.26, box.bottom - s * 0.22, s * 0.15, s * 0.22));
    // cup sign
    final sign = Offset(box.center.dx, box.top + s * 0.08);
    c.drawCircle(sign, s * 0.06, _f(Colors.white));
    c.drawRect(Rect.fromCenter(center: sign.translate(0, s * 0.005), width: s * 0.06, height: s * 0.05), _f(const Color(0xFF6D4C41)));
    TownArt._smoke(c, sign.translate(0, -s * 0.03), t, s * 0.5);
    // outside tables with umbrellas
    for (var i = 0; i < 2; i++) {
      final x = r.left + s * (0.25 + i * 0.5);
      final y = r.bottom - s * 0.06;
      c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 0.12, height: s * 0.035), _f(const Color(0xFF8A5A2B)));
      c.drawLine(Offset(x, y), Offset(x, y - s * 0.18), _st(const Color(0xFF5B3A1E), 1.2));
      c.drawArc(Rect.fromCenter(center: Offset(x, y - s * 0.18), width: s * 0.2, height: s * 0.16), math.pi, math.pi, true, _f(i == 0 ? const Color(0xFFE53935) : const Color(0xFFFFB300)));
    }
  }

  static void _gasStation(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.95);
    // little shop
    final shop = Rect.fromLTWH(r.right - s * 0.4, r.bottom - s * 0.44, s * 0.34, s * 0.32);
    TownArt._wall(c, shop, const Color(0xFFF5F5F0));
    c.drawRect(Rect.fromLTWH(shop.left - 2, shop.top - s * 0.04, shop.width + 4, s * 0.05), _f(const Color(0xFFE53935)));
    TownArt._window(c, Rect.fromLTWH(shop.left + s * 0.04, shop.top + s * 0.08, s * 0.14, s * 0.12), lit: true);
    TownArt._door(c, Rect.fromLTWH(shop.right - s * 0.12, shop.bottom - s * 0.17, s * 0.09, s * 0.17));
    // canopy
    final top = Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.74, s * 0.62, s * 0.1);
    c.drawRRect(RRect.fromRectAndRadius(top, Radius.circular(s * 0.02)), _f(const Color(0xFFE53935)));
    c.drawRect(Rect.fromLTWH(top.left, top.top + s * 0.03, top.width, s * 0.025), _f(Colors.white));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.1, top.bottom, s * 0.03, s * 0.5), _f(const Color(0xFFBDBDBD)));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.57, top.bottom, s * 0.03, s * 0.5), _f(const Color(0xFFBDBDBD)));
    // pump
    final pump = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + s * 0.28, r.bottom - s * 0.4, s * 0.14, s * 0.28), Radius.circular(s * 0.02));
    c.drawRRect(pump, _f(const Color(0xFF1E88E5)));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.3, r.bottom - s * 0.37, s * 0.1, s * 0.07), _f(const Color(0xFFB3E5FC)));
    c.drawLine(Offset(r.left + s * 0.42, r.bottom - s * 0.32), Offset(r.left + s * 0.47, r.bottom - s * 0.2), _st(const Color(0xFF212121), 1.5));
    // price sign
    c.drawLine(Offset(r.left + s * 0.76, r.bottom - s * 0.44), Offset(r.left + s * 0.76, r.bottom - s * 0.9), _st(const Color(0xFF5E6268), 1.6));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.68, r.bottom - s * 1.0, s * 0.16, s * 0.14), _f(const Color(0xFF212121)));
    c.drawCircle(Offset(r.left + s * 0.76, r.bottom - s * 0.93), s * 0.03, _f(math.sin(t * 2) > 0 ? const Color(0xFF69F0AE) : const Color(0xFF2E7D4F)));
  }

  static void _postOffice(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.64, s * 0.8, s * 0.52);
    TownArt._wall(c, box, const Color(0xFFF1E4D0));
    TownArt._tiledRoof(c, box, const Color(0xFF1565C0), s * 0.24);
    TownArt._window(c, Rect.fromLTWH(box.left + s * 0.1, box.top + s * 0.14, s * 0.16, s * 0.16), lit: true);
    TownArt._window(c, Rect.fromLTWH(box.right - s * 0.26, box.top + s * 0.14, s * 0.16, s * 0.16), lit: true);
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.07, box.bottom - s * 0.23, s * 0.14, s * 0.23), color: const Color(0xFF1565C0));
    // envelope sign
    final env = Rect.fromCenter(center: Offset(box.center.dx, box.top + s * 0.1), width: s * 0.16, height: s * 0.1);
    c.drawRect(env, _f(Colors.white));
    c.drawRect(env, _st(const Color(0xFF1565C0), 1.0));
    c.drawLine(env.topLeft, env.center, _st(const Color(0xFF1565C0), 1.0));
    c.drawLine(env.topRight, env.center, _st(const Color(0xFF1565C0), 1.0));
    // red mailbox
    final mb = RRect.fromRectAndRadius(Rect.fromLTWH(r.right - s * 0.12, r.bottom - s * 0.3, s * 0.1, s * 0.18), Radius.circular(s * 0.04));
    c.drawRRect(mb, _f(const Color(0xFFD32F2F)));
    c.drawRect(Rect.fromLTWH(r.right - s * 0.1, r.bottom - s * 0.26, s * 0.06, s * 0.015), _f(Colors.black));
  }

  static void _police(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.08, r.bottom - s * 0.7, s * 0.84, s * 0.58);
    TownArt._wall(c, box, const Color(0xFFCBD5E1));
    c.drawRect(Rect.fromLTWH(box.left, box.top, box.width, s * 0.1), _f(const Color(0xFF1E3A8A)));
    // badge
    final b = Offset(box.center.dx, box.top + s * 0.05);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? s * 0.055 : s * 0.025;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(b.dx + math.cos(a) * rad, b.dy + math.sin(a) * rad);
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    c.drawPath(star, _f(const Color(0xFFFFD54F)));
    TownArt._windowGrid(c, Rect.fromLTWH(box.left + s * 0.06, box.top + s * 0.14, box.width - s * 0.12, s * 0.2), 1, 4);
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.22, s * 0.16, s * 0.22), color: const Color(0xFF1E3A8A));
    // siren light on the roof
    final on = math.sin(t * 6) > 0;
    final lamp = Rect.fromLTWH(box.center.dx - s * 0.06, box.top - s * 0.07, s * 0.12, s * 0.07);
    c.drawRRect(RRect.fromRectAndRadius(lamp, Radius.circular(s * 0.03)), _f(on ? const Color(0xFFFF3B30) : const Color(0xFF2F6BFF)));
    c.drawCircle(lamp.center, s * 0.1, _f((on ? const Color(0xFFFF3B30) : const Color(0xFF2F6BFF)).withOpacity(0.18)));
  }

  static void _cinema(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r);
    final box = Rect.fromLTWH(r.left + s * 0.06, r.bottom - s * 0.78, s * 0.88, s * 0.66);
    TownArt._wall(c, box, const Color(0xFF3B2A5C));
    // marquee
    final sign = Rect.fromLTWH(box.left + s * 0.06, box.top + s * 0.08, box.width - s * 0.12, s * 0.16);
    c.drawRect(sign, _f(const Color(0xFF14101F)));
    c.drawRect(sign, _st(const Color(0xFFF2CE7C), 1.5));
    for (var i = 0; i < 9; i++) {
      final on = (i + (t * 4).floor()) % 2 == 0;
      c.drawCircle(Offset(sign.left + sign.width * (i + 0.5) / 9, sign.top + s * 0.02), s * 0.015, _f(on ? const Color(0xFFFFE08A) : const Color(0xFF6B5A2B)));
      c.drawCircle(Offset(sign.left + sign.width * (i + 0.5) / 9, sign.bottom - s * 0.02), s * 0.015, _f(!on ? const Color(0xFFFFE08A) : const Color(0xFF6B5A2B)));
    }
    // film reel
    c.drawCircle(sign.center, s * 0.055, _f(const Color(0xFFF2CE7C)));
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + t;
      c.drawCircle(sign.center.translate(math.cos(a) * s * 0.03, math.sin(a) * s * 0.03), s * 0.012, _f(const Color(0xFF14101F)));
    }
    // posters + doors
    for (var i = 0; i < 3; i++) {
      final p = Rect.fromLTWH(box.left + s * 0.1 + i * s * 0.26, box.top + s * 0.3, s * 0.16, s * 0.2);
      c.drawRect(p, _f([const Color(0xFFE53935), const Color(0xFF29B6F6), const Color(0xFFFFCA28)][i]));
      c.drawRect(p, _st(Colors.white, 1.0));
    }
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.1, box.bottom - s * 0.15, s * 0.2, s * 0.15), _f(const Color(0xFFF2CE7C)));
    c.drawRect(Rect.fromLTWH(box.center.dx - s * 0.005, box.bottom - s * 0.15, s * 0.01, s * 0.15), _f(const Color(0xFF3B2A5C)));
  }

  static void _hotel(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.95);
    final box = Rect.fromLTWH(r.left + s * 0.08, r.bottom - s * 1.38, s * 0.84, s * 1.26);
    TownArt._wall(c, box, const Color(0xFFF2E3C6));
    c.drawRect(Rect.fromLTWH(box.left - 2, box.top - s * 0.06, box.width + 4, s * 0.08), _f(const Color(0xFF8E3B2E)));
    TownArt._windowGrid(c, Rect.fromLTWH(box.left + s * 0.05, box.top + s * 0.08, box.width - s * 0.1, box.height - s * 0.42), 5, 5, litAlt: true);
    // awning + door
    TownArt._stripedAwning(c, Rect.fromLTWH(box.center.dx - s * 0.2, box.bottom - s * 0.3, s * 0.4, s * 0.08), const Color(0xFFB71C1C), Colors.white, 6);
    TownArt._door(c, Rect.fromLTWH(box.center.dx - s * 0.08, box.bottom - s * 0.2, s * 0.16, s * 0.2), color: const Color(0xFF4E342E));
    // sign on the roof
    final sign = Rect.fromCenter(center: Offset(box.center.dx, box.top - s * 0.18), width: s * 0.44, height: s * 0.14);
    c.drawRRect(RRect.fromRectAndRadius(sign, Radius.circular(s * 0.03)), _f(const Color(0xFF1A237E)));
    for (var i = 0; i < 3; i++) {
      final lit = ((t * 2).floor() + i) % 3 != 0;
      c.drawCircle(sign.center.translate((i - 1) * s * 0.12, 0), s * 0.035, _f(lit ? const Color(0xFFFFD54F) : const Color(0xFF6A5A1F)));
    }
    c.drawLine(Offset(sign.left + s * 0.06, sign.bottom), Offset(sign.left + s * 0.06, box.top - s * 0.05), _st(const Color(0xFF455A64), 1.5));
    c.drawLine(Offset(sign.right - s * 0.06, sign.bottom), Offset(sign.right - s * 0.06, box.top - s * 0.05), _st(const Color(0xFF455A64), 1.5));
  }

  // ==================================================================
  // EXTRA PARKS
  // ==================================================================
  static void _basketball(Canvas c, Rect r, double t) {
    final s = r.width;
    final court = Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.5, s * 0.92, s * 0.4);
    c.drawRect(court.inflate(s * 0.02), _f(const Color(0xFF3B3B44)));
    c.drawRect(court, _f(const Color(0xFFE0833A)));
    final line = _st(Colors.white.withOpacity(0.9), math.max(1.0, s * 0.02));
    c.drawRect(court.deflate(s * 0.03), line);
    c.drawLine(Offset(court.center.dx, court.top + s * 0.03), Offset(court.center.dx, court.bottom - s * 0.03), line);
    c.drawCircle(court.center, s * 0.07, line);
    c.drawRect(Rect.fromLTWH(court.left + s * 0.03, court.center.dy - s * 0.08, s * 0.14, s * 0.16), line);
    c.drawRect(Rect.fromLTWH(court.right - s * 0.17, court.center.dy - s * 0.08, s * 0.14, s * 0.16), line);
    // hoops
    for (final left in [true, false]) {
      final x = left ? court.left + s * 0.02 : court.right - s * 0.02;
      c.drawLine(Offset(x, court.bottom - s * 0.04), Offset(x, court.top - s * 0.22), _st(const Color(0xFF455A64), math.max(1.5, s * 0.035)));
      final bx = left ? x : x - s * 0.1;
      c.drawRect(Rect.fromLTWH(bx, court.top - s * 0.3, s * 0.1, s * 0.12), _f(Colors.white));
      c.drawRect(Rect.fromLTWH(bx, court.top - s * 0.3, s * 0.1, s * 0.12), _st(const Color(0xFFD32F2F), 1.0));
      c.drawOval(Rect.fromCenter(center: Offset(left ? x + s * 0.1 : x - s * 0.1, court.top - s * 0.17), width: s * 0.1, height: s * 0.04), _st(const Color(0xFFFF6D00), 1.5));
    }
    // bouncing ball
    final k = (t * 1.4) % 1.0;
    final by = court.center.dy - math.sin(k * math.pi) * s * 0.2;
    c.drawCircle(Offset(court.center.dx - s * 0.18, by), s * 0.035, _f(const Color(0xFFFF8F00)));
  }

  static void _pool(Canvas c, Rect r, double t) {
    final s = r.width;
    final deck = Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.62, s * 0.92, s * 0.52);
    c.drawRRect(RRect.fromRectAndRadius(deck, Radius.circular(s * 0.05)), _f(const Color(0xFFE8E0CF)));
    final water = deck.deflate(s * 0.07);
    c.drawRRect(RRect.fromRectAndRadius(water, Radius.circular(s * 0.04)), _f(const Color(0xFF29B6F6)));
    c.drawRRect(RRect.fromRectAndRadius(water.deflate(s * 0.03), Radius.circular(s * 0.03)), _f(const Color(0xFF4FC3F7)));
    final lane = _st(Colors.white.withOpacity(0.7), 1.0);
    for (var i = 1; i < 3; i++) {
      c.drawLine(Offset(water.left + s * 0.02, water.top + water.height * i / 3), Offset(water.right - s * 0.02, water.top + water.height * i / 3), lane);
    }
    for (var i = 0; i < 3; i++) {
      final ph = (t * 0.3 + i / 3) % 1.0;
      c.drawLine(Offset(water.left + ph * water.width, water.top + s * 0.06 + i * s * 0.1), Offset(water.left + ph * water.width + s * 0.1, water.top + s * 0.06 + i * s * 0.1), _st(Colors.white.withOpacity(0.55), 1.0));
    }
    // ladder + umbrella
    c.drawLine(Offset(water.right - s * 0.02, water.top), Offset(water.right - s * 0.02, water.top + s * 0.1), _st(const Color(0xFFBDBDBD), 1.5));
    c.drawLine(Offset(deck.left + s * 0.06, deck.top + s * 0.08), Offset(deck.left + s * 0.06, deck.top - s * 0.14), _st(const Color(0xFF5B3A1E), 1.2));
    c.drawArc(Rect.fromCenter(center: Offset(deck.left + s * 0.06, deck.top - s * 0.14), width: s * 0.22, height: s * 0.16), math.pi, math.pi, true, _f(const Color(0xFFFF7043)));
  }

  static void _carousel(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.9);
    final base = Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.2, s * 0.8, s * 0.1);
    c.drawRRect(RRect.fromRectAndRadius(base, Radius.circular(s * 0.04)), _f(const Color(0xFF8D6E63)));
    final cx = r.center.dx;
    c.drawRect(Rect.fromLTWH(cx - s * 0.03, r.bottom - s * 0.7, s * 0.06, s * 0.5), _f(const Color(0xFFFFD54F)));
    // horses on poles
    for (var i = 0; i < 4; i++) {
      final a = t * 0.9 + i * math.pi / 2;
      final x = cx + math.cos(a) * s * 0.3;
      final depth = math.sin(a);
      final bob = math.sin(t * 3 + i) * s * 0.025;
      final y = r.bottom - s * 0.36 + bob + depth * s * 0.02;
      c.drawLine(Offset(x, r.bottom - s * 0.6), Offset(x, r.bottom - s * 0.2), _st(const Color(0xFFFFE082), 1.2));
      final horse = Rect.fromCenter(center: Offset(x, y), width: s * 0.17, height: s * 0.1);
      c.drawOval(horse, _f([Colors.white, const Color(0xFFFFCC80), const Color(0xFFCE93D8), const Color(0xFF90CAF9)][i]));
      c.drawCircle(Offset(x + (math.cos(a) >= 0 ? s * 0.08 : -s * 0.08), y - s * 0.06), s * 0.03, _f(const Color(0xFF5B3A1E)));
    }
    // striped roof
    final roof = Path()
      ..moveTo(r.left + s * 0.04, r.bottom - s * 0.6)
      ..lineTo(cx, r.bottom - s * 0.92)
      ..lineTo(r.right - s * 0.04, r.bottom - s * 0.6)
      ..close();
    c.drawPath(roof, _f(const Color(0xFFE53935)));
    c.save();
    c.clipPath(roof);
    for (var i = 0; i < 8; i += 2) {
      c.drawRect(Rect.fromLTWH(r.left + s * 0.04 + i * s * 0.12, r.bottom - s * 0.95, s * 0.12, s * 0.4), _f(Colors.white));
    }
    c.restore();
    c.drawPath(roof, _st(const Color(0xFF8E1B18), 1.2));
    c.drawCircle(Offset(cx, r.bottom - s * 0.94), s * 0.03, _f(const Color(0xFFFFD54F)));
  }

  static void _ferrisWheel(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.8);
    final hub = Offset(r.center.dx, r.bottom - s * 0.95);
    final rad = s * 0.55;
    // A-frame legs
    final leg = _st(const Color(0xFF546E7A), math.max(2.0, s * 0.05));
    c.drawLine(hub, Offset(r.center.dx - s * 0.3, r.bottom - s * 0.1), leg);
    c.drawLine(hub, Offset(r.center.dx + s * 0.3, r.bottom - s * 0.1), leg);
    // wheel
    c.save();
    c.translate(hub.dx, hub.dy);
    final rim = _st(const Color(0xFFEF5350), math.max(2.0, s * 0.04));
    c.drawCircle(Offset.zero, rad, rim);
    c.drawCircle(Offset.zero, rad * 0.7, _st(const Color(0xFFFFCA28), math.max(1.0, s * 0.02)));
    final spoke = _st(const Color(0xFFCFD8DC), 1.2);
    const gondolas = 8;
    for (var i = 0; i < gondolas; i++) {
      final a = t * 0.25 + i * 2 * math.pi / gondolas;
      final p = Offset(math.cos(a) * rad, math.sin(a) * rad);
      c.drawLine(Offset.zero, p, spoke);
      // gondolas hang straight down
      final gp = p.translate(0, s * 0.06);
      c.drawLine(p, gp, _st(const Color(0xFF455A64), 1.0));
      final cols = [const Color(0xFF42A5F5), const Color(0xFF66BB6A), const Color(0xFFFFCA28), const Color(0xFFAB47BC)];
      final cab = RRect.fromRectAndRadius(Rect.fromCenter(center: gp.translate(0, s * 0.04), width: s * 0.1, height: s * 0.08), Radius.circular(s * 0.02));
      c.drawRRect(cab, _f(cols[i % cols.length]));
      c.drawRRect(cab, _st(Colors.white, 0.8));
    }
    c.restore();
    c.drawCircle(hub, s * 0.045, _f(const Color(0xFF37474F)));
  }

  // ==================================================================
  // NATURE / DECOR
  // ==================================================================
  static void _bush(Canvas c, Rect r, int seed) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.55);
    final cx = r.center.dx;
    final y = r.bottom - s * 0.2;
    c.drawCircle(Offset(cx - s * 0.12, y), s * 0.14, _f(const Color(0xFF2F7D32)));
    c.drawCircle(Offset(cx + s * 0.12, y), s * 0.14, _f(const Color(0xFF2F7D32)));
    c.drawCircle(Offset(cx, y - s * 0.08), s * 0.17, _f(const Color(0xFF43A047)));
    c.drawCircle(Offset(cx - s * 0.05, y - s * 0.13), s * 0.06, _f(const Color(0xFF7BCB7E).withOpacity(0.8)));
    if (seed % 3 == 0) {
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(cx + (i - 1.5) * s * 0.07, y - s * 0.04 + (i.isEven ? 0 : -s * 0.07)), s * 0.02, _f(const Color(0xFFE53935)));
      }
    }
  }

  static void _rock(Canvas c, Rect r, int col, int row) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.6);
    final h = _h(col, row);
    final cx = r.center.dx, by = r.bottom - s * 0.14;
    void stone(double dx, double w, double hh, Color color) {
      final p = Path()
        ..moveTo(cx + dx - w / 2, by)
        ..quadraticBezierTo(cx + dx - w * 0.55, by - hh, cx + dx - w * 0.1, by - hh)
        ..quadraticBezierTo(cx + dx + w * 0.5, by - hh * 0.9, cx + dx + w / 2, by)
        ..close();
      c.drawPath(p, _f(color));
      c.drawPath(p, _st(_sh(color, -0.25), 1.0));
      c.drawCircle(Offset(cx + dx - w * 0.15, by - hh * 0.55), w * 0.12, _f(Colors.white.withOpacity(0.2)));
    }

    stone(-s * 0.1, s * 0.3, s * 0.2, const Color(0xFF9E9E9E));
    stone(s * 0.14, s * 0.22, s * 0.14, const Color(0xFF8A8A8A));
    if (h % 2 == 0) {
      c.drawOval(Rect.fromCenter(center: Offset(cx - s * 0.16, by - s * 0.15), width: s * 0.12, height: s * 0.05), _f(const Color(0xFF6FA55A)));
    }
  }

  static void _busStop(Canvas c, Rect r) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.8);
    final pole = _st(const Color(0xFF546E7A), math.max(2.0, s * 0.045));
    final l = r.left + s * 0.14, rr = r.right - s * 0.14;
    c.drawLine(Offset(l, r.bottom - s * 0.1), Offset(l, r.bottom - s * 0.62), pole);
    c.drawLine(Offset(rr, r.bottom - s * 0.1), Offset(rr, r.bottom - s * 0.62), pole);
    final roof = Rect.fromLTRB(l - s * 0.05, r.bottom - s * 0.7, rr + s * 0.05, r.bottom - s * 0.6);
    c.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(s * 0.03)), _f(const Color(0xFF1976D2)));
    c.drawRect(Rect.fromLTRB(l + 1, r.bottom - s * 0.58, rr - 1, r.bottom - s * 0.25), _f(const Color(0xFFB3E5FC).withOpacity(0.5)));
    c.drawRect(Rect.fromLTWH(r.center.dx - s * 0.2, r.bottom - s * 0.27, s * 0.4, s * 0.04), _f(const Color(0xFF8A5A2B)));
    c.drawCircle(Offset(rr + s * 0.04, r.bottom - s * 0.5), s * 0.05, _f(Colors.white));
    c.drawCircle(Offset(rr + s * 0.04, r.bottom - s * 0.5), s * 0.05, _st(const Color(0xFFFBC02D), 1.8));
  }

  static void _car(Canvas c, Rect r) {
    final s = r.width;
    c.drawOval(Rect.fromCenter(center: Offset(r.center.dx, r.bottom - s * 0.1), width: s * 0.8, height: s * 0.14), _f(Colors.black.withOpacity(0.22)));
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + s * 0.1, r.bottom - s * 0.38, s * 0.8, s * 0.2), Radius.circular(s * 0.06));
    c.drawRRect(body, _f(const Color(0xFFD32F2F)));
    c.drawRRect(body, _st(const Color(0xFF7F1717), 1.0));
    final cabin = Path()
      ..moveTo(r.left + s * 0.28, r.bottom - s * 0.38)
      ..lineTo(r.left + s * 0.36, r.bottom - s * 0.56)
      ..lineTo(r.left + s * 0.66, r.bottom - s * 0.56)
      ..lineTo(r.left + s * 0.76, r.bottom - s * 0.38)
      ..close();
    c.drawPath(cabin, _f(const Color(0xFFE53935)));
    c.drawPath(cabin, _st(const Color(0xFF7F1717), 1.0));
    c.drawRect(Rect.fromLTRB(r.left + s * 0.4, r.bottom - s * 0.53, r.left + s * 0.5, r.bottom - s * 0.4), _f(const Color(0xFFB3E5FC)));
    c.drawRect(Rect.fromLTRB(r.left + s * 0.54, r.bottom - s * 0.53, r.left + s * 0.64, r.bottom - s * 0.4), _f(const Color(0xFFB3E5FC)));
    c.drawCircle(Offset(r.right - s * 0.12, r.bottom - s * 0.3), s * 0.025, _f(const Color(0xFFFFE08A)));
    for (final x in [r.left + s * 0.3, r.left + s * 0.7]) {
      c.drawCircle(Offset(x, r.bottom - s * 0.17), s * 0.07, _f(const Color(0xFF1B1B1F)));
      c.drawCircle(Offset(x, r.bottom - s * 0.17), s * 0.03, _f(const Color(0xFFBDBDBD)));
    }
  }

  static void _bus(Canvas c, Rect r) {
    final s = r.width;
    c.drawOval(Rect.fromCenter(center: Offset(r.center.dx, r.bottom - s * 0.1), width: s * 0.92, height: s * 0.14), _f(Colors.black.withOpacity(0.22)));
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.56, s * 0.92, s * 0.38), Radius.circular(s * 0.06));
    c.drawRRect(body, _f(const Color(0xFFFBC02D)));
    c.drawRRect(body, _st(const Color(0xFF8D6A00), 1.0));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.04, r.bottom - s * 0.3, s * 0.92, s * 0.04), _f(const Color(0xFF3B3B44)));
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(r.left + s * 0.12 + i * s * 0.17, r.bottom - s * 0.5, s * 0.13, s * 0.14), _f(const Color(0xFFB3E5FC)));
    }
    c.drawRect(Rect.fromLTWH(r.right - s * 0.2, r.bottom - s * 0.5, s * 0.1, s * 0.22), _f(const Color(0xFF81D4FA)));
    for (final x in [r.left + s * 0.25, r.left + s * 0.75]) {
      c.drawCircle(Offset(x, r.bottom - s * 0.17), s * 0.07, _f(const Color(0xFF1B1B1F)));
      c.drawCircle(Offset(x, r.bottom - s * 0.17), s * 0.03, _f(const Color(0xFFBDBDBD)));
    }
  }

  // ==================================================================
  // LEGO
  // ==================================================================
  /// One brick: front face, lighter top face with round studs.
  static void _brick(Canvas c, double left, double bottom, double w, double h, Color color, {int studs = 2}) {
    final depth = w * 0.16;
    final front = Rect.fromLTWH(left, bottom - h, w, h);
    final top = Rect.fromLTWH(left, bottom - h - depth, w, depth);
    c.drawRect(front, _f(color));
    c.drawRect(Rect.fromLTRB(front.right - w * 0.1, front.top, front.right, front.bottom), _f(Colors.black.withOpacity(0.14)));
    c.drawRect(front, _st(_sh(color, -0.25), 1.0));
    c.drawRect(top, _f(_sh(color, 0.1)));
    c.drawRect(top, _st(_sh(color, -0.25), 1.0));
    final sw = w / studs;
    for (var i = 0; i < studs; i++) {
      final centre = Offset(left + sw * (i + 0.5), top.center.dy);
      final stud = Rect.fromCenter(center: centre, width: sw * 0.58, height: depth * 0.8);
      c.drawOval(stud.translate(0, depth * 0.12), _f(_sh(color, -0.12)));
      c.drawOval(stud.translate(0, -depth * 0.08), _f(_sh(color, 0.16)));
      c.drawOval(stud.translate(0, -depth * 0.08), _st(_sh(color, -0.2), 0.8));
    }
  }

  static void _legoPlate(Canvas c, Rect r) {
    final s = r.width;
    c.drawRect(r, _f(const Color(0xFF2E9E4F)));
    c.drawRect(r.deflate(s * 0.02), _st(const Color(0xFF1E6B35), 1.2));
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        final p = Offset(r.left + s * (i + 0.5) / 4, r.top + s * (j + 0.5) / 4);
        c.drawCircle(p.translate(0, s * 0.012), s * 0.07, _f(const Color(0xFF1E7A3A)));
        c.drawCircle(p, s * 0.07, _f(const Color(0xFF47C56E)));
        c.drawCircle(p, s * 0.07, _st(const Color(0xFF1E7A3A), 0.8));
      }
    }
  }

  static void _legoSingle(Canvas c, Rect r, Color color) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.8);
    _brick(c, r.left + s * 0.12, r.bottom - s * 0.14, s * 0.76, s * 0.3, color, studs: 3);
  }

  static void _legoTree(Canvas c, Rect r) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.6);
    _brick(c, r.center.dx - s * 0.08, r.bottom - s * 0.12, s * 0.16, s * 0.22, const Color(0xFF795548), studs: 1);
    _brick(c, r.center.dx - s * 0.34, r.bottom - s * 0.3, s * 0.68, s * 0.2, const Color(0xFF2E7D32), studs: 4);
    _brick(c, r.center.dx - s * 0.26, r.bottom - s * 0.48, s * 0.52, s * 0.2, const Color(0xFF388E3C), studs: 3);
    _brick(c, r.center.dx - s * 0.17, r.bottom - s * 0.66, s * 0.34, s * 0.2, const Color(0xFF43A047), studs: 2);
    _brick(c, r.center.dx - s * 0.09, r.bottom - s * 0.84, s * 0.18, s * 0.18, const Color(0xFF66BB6A), studs: 1);
  }

  static void _legoFigure(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.5);
    final cx = r.center.dx;
    final wave = math.sin(t * 3) * s * 0.03;
    final yb = r.bottom - s * 0.12;
    // legs
    c.drawRect(Rect.fromLTWH(cx - s * 0.12, yb - s * 0.2, s * 0.11, s * 0.2), _f(const Color(0xFF1565C0)));
    c.drawRect(Rect.fromLTWH(cx + s * 0.01, yb - s * 0.2, s * 0.11, s * 0.2), _f(const Color(0xFF0D47A1)));
    // torso
    final torso = RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.16, yb - s * 0.46, s * 0.32, s * 0.28), Radius.circular(s * 0.03));
    c.drawRRect(torso, _f(const Color(0xFFD32F2F)));
    c.drawRRect(torso, _st(const Color(0xFF7F1717), 1.0));
    // arms
    c.drawRect(Rect.fromLTWH(cx - s * 0.23, yb - s * 0.44, s * 0.07, s * 0.2), _f(const Color(0xFFD32F2F)));
    c.drawRect(Rect.fromLTWH(cx + s * 0.16, yb - s * 0.46 - wave, s * 0.07, s * 0.2), _f(const Color(0xFFD32F2F)));
    c.drawCircle(Offset(cx - s * 0.195, yb - s * 0.23), s * 0.035, _f(const Color(0xFFFFCA28)));
    c.drawCircle(Offset(cx + s * 0.195, yb - s * 0.27 - wave), s * 0.035, _f(const Color(0xFFFFCA28)));
    // head
    final head = RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.12, yb - s * 0.68, s * 0.24, s * 0.22), Radius.circular(s * 0.08));
    c.drawRRect(head, _f(const Color(0xFFFFCA28)));
    c.drawRRect(head, _st(const Color(0xFFB88400), 1.0));
    c.drawCircle(Offset(cx - s * 0.045, yb - s * 0.6), s * 0.014, _f(Colors.black));
    c.drawCircle(Offset(cx + s * 0.045, yb - s * 0.6), s * 0.014, _f(Colors.black));
    c.drawArc(Rect.fromCenter(center: Offset(cx, yb - s * 0.55), width: s * 0.12, height: s * 0.08), 0.2, math.pi - 0.4, false, _st(Colors.black, 1.0));
    // top stud + cap
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.06, yb - s * 0.73, s * 0.12, s * 0.06), Radius.circular(s * 0.02)), _f(const Color(0xFFFFCA28)));
    c.drawRect(Rect.fromLTWH(cx - s * 0.13, yb - s * 0.7, s * 0.26, s * 0.05), _f(const Color(0xFF1565C0)));
  }

  static void _legoCar(Canvas c, Rect r, double t) {
    final s = r.width;
    c.drawOval(Rect.fromCenter(center: Offset(r.center.dx, r.bottom - s * 0.1), width: s * 0.84, height: s * 0.14), _f(Colors.black.withOpacity(0.22)));
    final bob = math.sin(t * 5) * s * 0.006;
    _brick(c, r.left + s * 0.08, r.bottom - s * 0.2 + bob, s * 0.84, s * 0.2, const Color(0xFFFBC02D), studs: 4);
    _brick(c, r.left + s * 0.26, r.bottom - s * 0.4 + bob, s * 0.46, s * 0.17, const Color(0xFFD32F2F), studs: 2);
    c.drawRect(Rect.fromLTWH(r.left + s * 0.31, r.bottom - s * 0.54 + bob, s * 0.15, s * 0.1), _f(const Color(0xFF81D4FA)));
    c.drawRect(Rect.fromLTWH(r.left + s * 0.52, r.bottom - s * 0.54 + bob, s * 0.15, s * 0.1), _f(const Color(0xFF81D4FA)));
    for (final x in [r.left + s * 0.26, r.left + s * 0.74]) {
      c.drawCircle(Offset(x, r.bottom - s * 0.14), s * 0.085, _f(const Color(0xFF212121)));
      c.drawCircle(Offset(x, r.bottom - s * 0.14), s * 0.04, _f(const Color(0xFFE0E0E0)));
      c.drawCircle(Offset(x, r.bottom - s * 0.14), s * 0.012, _f(const Color(0xFF424242)));
    }
  }

  static void _legoHouse(Canvas c, Rect r) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.9);
    final left = r.left + s * 0.1;
    final w = s * 0.8;
    // walls: 3 rows of bricks with staggered seams
    final wallBottom = r.bottom - s * 0.12;
    final rowH = s * 0.15;
    final wallTop = wallBottom - rowH * 3;
    c.drawRect(Rect.fromLTRB(left, wallTop, left + w, wallBottom), _f(const Color(0xFFE53935)));
    for (var row = 0; row < 3; row++) {
      final y = wallBottom - rowH * (row + 1);
      c.drawLine(Offset(left, y), Offset(left + w, y), _st(const Color(0xFF8E1B18), 1.0));
      final off = row.isEven ? 0.0 : w / 8;
      for (var x = left + off + w / 4; x < left + w; x += w / 4) {
        c.drawLine(Offset(x, y), Offset(x, y + rowH), _st(const Color(0xFF8E1B18), 1.0));
      }
    }
    c.drawRect(Rect.fromLTRB(left, wallTop, left + w, wallBottom), _st(const Color(0xFF8E1B18), 1.2));
    // stepped roof of studded bricks
    final steps = [
      [0.0, 1.0],
      [0.12, 0.76],
      [0.24, 0.52],
      [0.36, 0.28],
    ];
    for (var i = 0; i < steps.length; i++) {
      final sw = w * steps[i][1] + s * 0.06;
      final sl = left + w * steps[i][0] - s * 0.03;
      _brick(c, sl, wallTop - rowH * 0.9 * i, sw, rowH * 0.9, const Color(0xFF1976D2), studs: math.max(1, 4 - i));
    }
    // door + window
    c.drawRect(Rect.fromLTWH(left + w * 0.58, wallBottom - rowH * 1.9, w * 0.2, rowH * 1.9), _f(const Color(0xFFFBC02D)));
    c.drawRect(Rect.fromLTWH(left + w * 0.58, wallBottom - rowH * 1.9, w * 0.2, rowH * 1.9), _st(const Color(0xFF8D6A00), 1.0));
    c.drawRect(Rect.fromLTWH(left + w * 0.14, wallBottom - rowH * 2.2, w * 0.24, rowH * 1.1), _f(const Color(0xFF81D4FA)));
    c.drawRect(Rect.fromLTWH(left + w * 0.14, wallBottom - rowH * 2.2, w * 0.24, rowH * 1.1), _st(Colors.white, 1.5));
  }

  static void _legoTower(Canvas c, Rect r) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 0.7);
    final colors = [
      const Color(0xFFD32F2F),
      const Color(0xFF1976D2),
      const Color(0xFFFBC02D),
      const Color(0xFF388E3C),
      const Color(0xFFD32F2F),
      const Color(0xFF1976D2),
    ];
    var bottom = r.bottom - s * 0.1;
    for (var i = 0; i < colors.length; i++) {
      final w = s * (0.62 - i * 0.04);
      final x = r.center.dx - w / 2 + (i.isEven ? s * 0.02 : -s * 0.02);
      _brick(c, x, bottom, w, s * 0.19, colors[i], studs: 3);
      bottom -= s * 0.19;
    }
    // little flag
    final top = Offset(r.center.dx, bottom - s * 0.1);
    c.drawLine(top, top.translate(0, -s * 0.2), _st(const Color(0xFF5D4037), 1.4));
    c.drawRect(Rect.fromLTWH(top.dx, top.dy - s * 0.2, s * 0.14, s * 0.09), _f(const Color(0xFFE53935)));
  }

  static void _legoCastle(Canvas c, Rect r, double t) {
    final s = r.width;
    TownArt._groundShadow(c, r, wf: 1.0);
    const stone = Color(0xFF9E9E9E);
    final bottom = r.bottom - s * 0.1;
    // keep (middle) - 4 bricks high
    var b = bottom;
    for (var i = 0; i < 5; i++) {
      _brick(c, r.left + s * 0.28, b, s * 0.44, s * 0.17, i.isEven ? stone : const Color(0xFFB0B0B0), studs: 4);
      b -= s * 0.17;
    }
    // side towers
    for (final left in [true, false]) {
      final x = left ? r.left + s * 0.04 : r.right - s * 0.04 - s * 0.24;
      var tb = bottom;
      for (var i = 0; i < 4; i++) {
        _brick(c, x, tb, s * 0.24, s * 0.17, i.isEven ? const Color(0xFFB0B0B0) : stone, studs: 2);
        tb -= s * 0.17;
      }
      // pointed blue roof of two bricks
      _brick(c, x - s * 0.01, tb, s * 0.26, s * 0.12, const Color(0xFF1976D2), studs: 2);
      _brick(c, x + s * 0.05, tb - s * 0.12, s * 0.14, s * 0.12, const Color(0xFF2196F3), studs: 1);
    }
    // gate
    final gate = RRect.fromRectAndCorners(
      Rect.fromLTWH(r.center.dx - s * 0.08, bottom - s * 0.26, s * 0.16, s * 0.26),
      topLeft: Radius.circular(s * 0.08),
      topRight: Radius.circular(s * 0.08),
    );
    c.drawRRect(gate, _f(const Color(0xFF5D4037)));
    for (var i = 1; i < 4; i++) {
      c.drawLine(Offset(gate.left + gate.width * i / 4, gate.top + s * 0.04), Offset(gate.left + gate.width * i / 4, gate.bottom), _st(const Color(0xFF3E2723), 1.0));
    }
    // flag
    final pole = Offset(r.center.dx, b - s * 0.1);
    TownArt._flag(c, pole, s * 0.28, t, const Color(0xFFE53935));
  }
}
