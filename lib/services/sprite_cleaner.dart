// Makes sure character art never shows a white (or light-grey/checkerboard)
// box behind it. Some PNGs come out of image generators with the "background"
// baked in as opaque white pixels instead of real transparency; drawn over
// the dark game UI that shows up as an ugly white square.
//
// removeWhiteBackground() flood-fills inward from the image border and turns
// every connected near-white/neutral-light pixel transparent. Because it only
// walks in from the outside, white parts INSIDE a character (a knight's
// white plume, a panda's face) are left alone. Images that already have a
// transparent background are detected (their corners aren't opaque-white)
// and returned untouched, so it's safe to run on everything.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class SpriteCleaner {
  SpriteCleaner._();

  static final Map<String, Future<ui.Image?>> _assetCache = {};

  /// Loads a bundled PNG (e.g. 'assets/kenney/units/knight.png') with any
  /// white background removed. Cached. Resolves to null if the asset doesn't
  /// exist, so callers can fall back to procedural art.
  static Future<ui.Image?> loadAsset(String assetPath) =>
      _assetCache.putIfAbsent(assetPath, () => _load(assetPath));

  static Future<ui.Image?> _load(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return await removeWhiteBackground(frame.image);
    } catch (_) {
      return null;
    }
  }

  // "Background-ish": opaque and light and roughly grey/white (covers pure
  // white plus the light-grey squares of a fake transparency checkerboard).
  static bool _isBg(Uint8List px, int i) {
    final a = px[i + 3];
    if (a < 200) return false;
    final r = px[i], g = px[i + 1], b = px[i + 2];
    final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
    return mn >= 205 && (mx - mn) <= 16;
  }

  /// Crops away the empty transparent border around a character and re-centres
  /// what's left in a SQUARE canvas (feet on the bottom edge), so it keeps its
  /// proportions when drawn into the square sprite box but fills it instead of
  /// looking tiny inside a lot of padding. Idempotent: an image that is already
  /// tight (content covers >= 96% of both sides) is returned untouched.
  static Future<ui.Image> trimToContent(ui.Image src, {int alphaThreshold = 12, bool square = true}) async {
    final w = src.width;
    final h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null || w < 2 || h < 2) return src;
    final px = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);

    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      final row = y * w * 4;
      for (var x = 0; x < w; x++) {
        if (px[row + x * 4 + 3] > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return src; // fully transparent: nothing to trim
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;
    if (!square) {
      // Exact-fit crop (scenery: trees/grass/mountains keep their own aspect).
      if (cw >= w - 2 && ch >= h - 2) return src;
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawImageRect(
        src,
        ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cw.toDouble(), ch.toDouble()),
        ui.Rect.fromLTWH(0, 0, cw.toDouble(), ch.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      return rec.endRecording().toImage(cw, ch);
    }
    final side = cw > ch ? cw : ch;
    if (cw >= w * 0.96 && ch >= h * 0.96 && w == h) return src;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final dx = (side - cw) / 2.0;
    final dy = (side - ch).toDouble(); // bottom-aligned
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cw.toDouble(), ch.toDouble()),
      ui.Rect.fromLTWH(dx, dy, cw.toDouble(), ch.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final pic = recorder.endRecording();
    return pic.toImage(side, side);
  }

  static Future<ui.Image> removeWhiteBackground(ui.Image src) async {
    final w = src.width;
    final h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null || w < 2 || h < 2) return src;
    final view = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);

    // Only act if the image really has a solid light backdrop (checked on
    // the raw view first so already-transparent art costs almost nothing).
    final corners = <int>[0, (w - 1) * 4, (h - 1) * w * 4, ((h - 1) * w + (w - 1)) * 4];
    var bgCorners = 0;
    for (final i in corners) {
      if (_isBg(view, i)) bgCorners++;
    }
    if (bgCorners < 3) return src;
    final px = Uint8List.fromList(view);

    final visited = Uint8List(w * h);
    final stack = Int32List(w * h);
    var sp = 0;

    void push(int x, int y) {
      final idx = y * w + x;
      if (visited[idx] == 1) return;
      if (!_isBg(px, idx * 4)) return;
      visited[idx] = 1;
      stack[sp++] = idx;
    }

    for (var x = 0; x < w; x++) {
      push(x, 0);
      push(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      push(0, y);
      push(w - 1, y);
    }
    while (sp > 0) {
      final idx = stack[--sp];
      final x = idx % w;
      final y = idx ~/ w;
      if (x > 0) push(x - 1, y);
      if (x < w - 1) push(x + 1, y);
      if (y > 0) push(x, y - 1);
      if (y < h - 1) push(x, y + 1);
    }

    // Feather the halo: light pixels touching the removed area fade out
    // instead of leaving a thin white outline around the character.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        if (visited[idx] == 1) continue;
        final touches = (x > 0 && visited[idx - 1] == 1) ||
            (x < w - 1 && visited[idx + 1] == 1) ||
            (y > 0 && visited[idx - w] == 1) ||
            (y < h - 1 && visited[idx + w] == 1);
        if (!touches) continue;
        final i = idx * 4;
        final r = px[i], g = px[i + 1], b = px[i + 2];
        final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (mn > 170) {
          final keep = ((255 - mn) / 85.0).clamp(0.0, 1.0);
          px[i + 3] = (px[i + 3] * keep).round();
        }
      }
    }
    for (var idx = 0; idx < w * h; idx++) {
      if (visited[idx] == 1) px[idx * 4 + 3] = 0;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }
}
