// Paints the town. The world is ENDLESS, so there is no big canvas any more:
// a small TownCamera (centre + zoom) decides which tiles are on screen and
// only those are drawn: ground, endless greenery, flat pieces (streets,
// fields, rivers, rails, bridges), then standing pieces row by row so tall
// buildings and trees overlap the ones behind them.
import 'package:flutter/material.dart';

import '../constants/town_data.dart';
import 'town_art.dart';

class TownLayout {
  TownLayout._();

  static const double tile = 64.0;

  static Rect cellRect(int col, int row) => Rect.fromLTWH(col * tile, row * tile, tile, tile);

  /// (col,row) for a point in WORLD coordinates (pixels), or null outside the world.
  static ({int col, int row})? cellAt(Offset world) {
    final col = (world.dx / tile).floor();
    final row = (world.dy / tile).floor();
    if (!TownData.inWorld(col, row)) return null;
    return (col: col, row: row);
  }

  static Offset centreOf(int col, int row) => Offset((col + 0.5) * tile, (row + 0.5) * tile);
}

/// Where the player is looking: centre of the screen in world pixels + zoom.
class TownCamera extends ChangeNotifier {
  static const double minScale = 0.25;
  static const double maxScale = 2.5;

  double cx;
  double cy;
  double scale;

  TownCamera({this.cx = 0, this.cy = 0, this.scale = 1.0});

  void set(double x, double y, double s) {
    cx = x;
    cy = y;
    scale = s.clamp(minScale, maxScale).toDouble();
    final lim = TownData.worldLimit * TownLayout.tile;
    cx = cx.clamp(-lim, lim).toDouble();
    cy = cy.clamp(-lim, lim).toDouble();
    notifyListeners();
  }

  /// Moves the view by a finger drag of [dx],[dy] screen pixels.
  void panBy(double dx, double dy) => set(cx - dx / scale, cy - dy / scale, scale);

  /// Zooms by [factor] keeping the world point under [focal] (screen coords) fixed.
  void zoomAt(double factor, Offset focal, Size vp) {
    final before = screenToWorld(focal, vp);
    final ns = (scale * factor).clamp(minScale, maxScale).toDouble();
    // world point under focal after the zoom: (focal - vp/2)/ns + c' == before
    final ncx = before.dx - (focal.dx - vp.width / 2) / ns;
    final ncy = before.dy - (focal.dy - vp.height / 2) / ns;
    set(ncx, ncy, ns);
  }

  Offset screenToWorld(Offset p, Size vp) =>
      Offset((p.dx - vp.width / 2) / scale + cx, (p.dy - vp.height / 2) / scale + cy);
}

class TownPainter extends CustomPainter {
  final Map<int, String> grid;
  final Animation<double> time; // 0..1 over 1000 s (see TownScreen)
  final TownCamera camera;
  final int? selectedKey;
  final bool showGrid;
  final bool demolishMode;

  TownPainter({
    required this.grid,
    required this.time,
    required this.camera,
    required this.selectedKey,
    required this.showGrid,
    required this.demolishMode,
  }) : super(repaint: Listenable.merge([time, camera]));

  static const double _tile = TownLayout.tile;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value * 1000.0;
    final scale = camera.scale;

    // --- camera transform ---
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-camera.cx, -camera.cy);

    final halfW = size.width / 2 / scale;
    final halfH = size.height / 2 / scale;
    final vis = Rect.fromLTRB(camera.cx - halfW, camera.cy - halfH, camera.cx + halfW, camera.cy + halfH);

    final lim = TownData.worldLimit;
    final c0 = ((vis.left / _tile).floor() - 1).clamp(-lim, lim).toInt();
    final c1 = ((vis.right / _tile).ceil() + 1).clamp(-lim, lim).toInt();
    final r0 = ((vis.top / _tile).floor() - 1).clamp(-lim, lim).toInt();
    // tall pieces stick up out of their tile, so look a bit further down
    final r1 = ((vis.bottom / _tile).ceil() + 3).clamp(-lim, lim).toInt();

    final detail = scale >= 0.45;

    // --- endless grass ---
    canvas.drawRect(vis.inflate(_tile), Paint()..color = const Color(0xFF6DBB4E));
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        TownArt.drawGround(canvas, TownLayout.cellRect(col, row), col, row, detail: detail);
      }
    }

    // --- flat layer: wild flowers/grass, streets, fields, water, rails ---
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        final rect = TownLayout.cellRect(col, row);
        final id = grid[TownData.key(col, row)];
        if (id == null) {
          if (scale >= 0.35) {
            final kind = TownArtX.ambient(col, row);
            if (kind == TownArtX.ambFlowers || kind == TownArtX.ambGrass) {
              TownArtX.drawAmbientFlat(canvas, kind, rect, col, row, t);
            }
          }
          continue;
        }
        if (TownArt.isRoadId(id)) {
          TownArt.drawRoad(canvas, id, rect, _mask(col, row, TownArt.connectsRoad), col, row);
        } else if (TownArt.isFieldId(id)) {
          TownArt.drawField(canvas, id, rect, _maskSame(col, row, id), t, col, row);
        } else if (TownArt.isWaterId(id)) {
          TownArtX.drawWater(canvas, id, rect, _mask(col, row, TownArt.connectsWater), t, col, row);
        } else if (TownArt.isOnWaterId(id)) {
          final wm = _mask(col, row, TownArt.connectsWater);
          TownArtX.drawWater(canvas, 'river', rect, wm, t, col, row);
          TownArt.draw(canvas, id, rect, t, col: col, row: row, roadMask: wm);
        } else if (TownArt.isRailId(id)) {
          TownArtX.drawRail(canvas, rect, _mask(col, row, TownArt.connectsRail), col, row);
        } else if (id == 'lego_plate') {
          TownArt.draw(canvas, id, rect, t, col: col, row: row);
        }
      }
    }

    // --- placement grid hint ---
    if (showGrid && scale > 0.35) {
      final line = Paint()
        ..color = (demolishMode ? Colors.redAccent : Colors.white).withOpacity(0.28)
        ..strokeWidth = 1 / scale;
      final top = r0 * _tile;
      final bottom = (r1 + 1) * _tile;
      final left = c0 * _tile;
      final right = (c1 + 1) * _tile;
      for (var i = c0; i <= c1 + 1; i++) {
        canvas.drawLine(Offset(i * _tile, top), Offset(i * _tile, bottom), line);
      }
      for (var i = r0; i <= r1 + 1; i++) {
        canvas.drawLine(Offset(left, i * _tile), Offset(right, i * _tile), line);
      }
    }

    // --- standing layer: buildings + endless trees/bushes/rocks, back to front ---
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        final rect = TownLayout.cellRect(col, row);
        final id = grid[TownData.key(col, row)];
        if (id == null) {
          final kind = TownArtX.ambient(col, row);
          if (kind >= TownArtX.ambTree && kind <= TownArtX.ambRock) {
            TownArtX.drawAmbientTall(canvas, kind, rect, t, col, row);
          }
          continue;
        }
        final isTrain = id == 'train' || id == 'train_wagon';
        if (TownArt.isFlatId(id) && !isTrain) continue;
        final mask = isTrain ? _mask(col, row, TownArt.connectsRail) : 0;
        TownArt.draw(canvas, id, rect, t, col: col, row: row, roadMask: mask);
      }
    }

    // --- selection ---
    final sk = selectedKey;
    if (sk != null) {
      final r = TownLayout.cellRect(TownData.colOf(sk), TownData.rowOf(sk));
      final color = demolishMode ? Colors.redAccent : const Color(0xFFF2CE7C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / scale.clamp(0.6, 2.5),
      );
    }

    canvas.restore();
  }

  /// Which of the 4 neighbours satisfy [test] (bit mask north/east/south/west).
  int _mask(int col, int row, bool Function(String?) test) {
    var m = 0;
    if (test(grid[TownData.key(col, row - 1)])) m |= TownArt.north;
    if (test(grid[TownData.key(col + 1, row)])) m |= TownArt.east;
    if (test(grid[TownData.key(col, row + 1)])) m |= TownArt.south;
    if (test(grid[TownData.key(col - 1, row)])) m |= TownArt.west;
    return m;
  }

  int _maskSame(int col, int row, String id) => _mask(col, row, (o) => o == id);

  @override
  bool shouldRepaint(covariant TownPainter old) => true;
}
