// Shows a character's picture in menu screens (Army, Collection).
//   1. If the PNG exists, it's drawn with its white background stripped
//      (SpriteCleaner) — never a white box.
//   2. If there's no PNG yet, a code-drawn version of the character is shown
//      instead (CreaturePainter), also on a transparent background.
//   3. If neither exists (e.g. a tower with no art yet), [fallbackIcon] is
//      shown so the slot is never blank.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/creature_painter.dart';
import '../services/sprite_cleaner.dart';
import '../services/sprite_registry.dart';

class SpriteThumb extends StatefulWidget {
  final String spriteName;
  final double size;

  /// 0 = normal, up to 1 = fully blacked-out silhouette (for locked units).
  final double dim;
  final bool facingLeft;
  final IconData? fallbackIcon;
  final Color? fallbackColor;

  const SpriteThumb({
    super.key,
    required this.spriteName,
    required this.size,
    this.dim = 0,
    this.facingLeft = false,
    this.fallbackIcon,
    this.fallbackColor,
  });

  @override
  State<SpriteThumb> createState() => _SpriteThumbState();
}

class _SpriteThumbState extends State<SpriteThumb> {
  late Future<ui.Image?> _future;

  @override
  void initState() {
    super.initState();
    _future = _futureFor(widget.spriteName);
  }

  @override
  void didUpdateWidget(SpriteThumb old) {
    super.didUpdateWidget(old);
    if (old.spriteName != widget.spriteName) _future = _futureFor(widget.spriteName);
  }

  Future<ui.Image?> _futureFor(String name) {
    final path = SpriteRegistry.paths[name];
    if (path == null) return Future.value(null);
    return SpriteCleaner.loadAsset(path);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    Widget content = FutureBuilder<ui.Image?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(width: size, height: size);
        }
        final image = snap.data;
        if (image != null) {
          return SizedBox(
            width: size,
            height: size,
            child: RawImage(
              image: image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              scale: 1.0,
            ),
          );
        }
        final kind = CreaturePainter.kindFor(widget.spriteName);
        if (kind != null) {
          return CustomPaint(
            size: Size.square(size),
            painter: CreatureThumbPainter(kind, facingLeft: widget.facingLeft),
          );
        }
        if (widget.fallbackIcon != null) {
          return SizedBox(
            width: size,
            height: size,
            child: Icon(widget.fallbackIcon, size: size * 0.7, color: widget.fallbackColor ?? Colors.white70),
          );
        }
        return SizedBox(width: size, height: size);
      },
    );

    if (widget.dim > 0) {
      content = ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: widget.dim.clamp(0.0, 1.0)), BlendMode.srcATop),
        child: content,
      );
    }
    return content;
  }
}

/// Round menu avatar: a soft tinted disc (never white) with the character's
/// picture on top. Locked characters are shown darkened with a small lock
/// badge, so you can still see who they are.
class UnitAvatar extends StatelessWidget {
  final String spriteName;
  final double radius;
  final bool locked;
  final Color accent;
  final IconData? fallbackIcon;

  /// How dark a locked character is drawn (0 = normal, 1 = pure silhouette).
  final double lockedDim;

  const UnitAvatar({
    super.key,
    required this.spriteName,
    required this.radius,
    required this.accent,
    this.locked = false,
    this.fallbackIcon,
    this.lockedDim = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.25)),
          ),
          SpriteThumb(
            spriteName: spriteName,
            size: d * 0.9,
            dim: locked ? lockedDim : 0,
            fallbackIcon: fallbackIcon,
            fallbackColor: accent,
          ),
          if (locked)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF241608)),
                child: Icon(Icons.lock, size: radius * 0.55, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
