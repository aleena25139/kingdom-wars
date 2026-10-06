// Renders one castle (player or enemy). Reads Castle model fields each
// frame — position never changes, but level (player only, changes the
// sprite) and hp (drives the health bar) do.
//
// The player castle has 100 designs x 7 build stages (700 images total,
// see CastleArtData/SpriteRegistry.pathForCastle). Every 7 upgrades
// finishes one design and starts the next; after design #100 the art loops
// back to #1 while the level number itself keeps climbing forever. Unlike
// the rest of the sprite roster these aren't preloaded up front (700 images
// would be wasteful) — they're loaded on demand the first time each one is
// needed and cached by Flame's Images afterward.
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart'
    show Canvas, Colors, TextStyle, FontWeight, Color, Paint, Path, Size;

import '../../constants/castle_art_data.dart';
import '../../models/castle.dart';
import '../../models/level.dart';
import '../../services/castle_painter.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';
import 'health_bar_component.dart';
import 'shadow_helper.dart';

class CastleComponent extends PositionComponent {
  final Castle castle;
  final KingdomWarsGame game;

  SpriteComponent? _sprite;
  late final HealthBarComponent _healthBar;
  TextComponent? _levelBadge;
  int _renderedLevel = -1;
  bool _usingIceArt = false;
  bool _procedural = false; // no PNG shipped -> CastlePainter draws it
  double _time = 0;

  CastleComponent({required this.castle, required this.game})
      : super(size: Vector2.all(140), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = game.worldToScreen(castle.x, castle.y);
    _healthBar = HealthBarComponent(
      size: Vector2(120, 10),
      position: Vector2(size.x / 2, -20),
    );
    add(_healthBar);
    await _refreshSprite();
  }

  Future<void> _refreshSprite() async {
    String assetPath;
    _usingIceArt = false;
    _procedural = false;
    if (castle.owner == CastleOwner.player) {
      final castleNumber = CastleArtData.castleNumberForLevel(castle.level);
      final stageNumber = CastleArtData.stageNumberForLevel(castle.level);
      assetPath = SpriteRegistry.pathForCastle(castleNumber, stageNumber);
    } else {
      assetPath = SpriteRegistry.pathFor('castle_evil');
    }
    var fileName = assetPath.replaceFirst('assets/', '');

    // Frozen Pass: prefer the ice castle art for the current stage, then the
    // single ice_castle.png, then fall back to the normal castle + snow cap.
    if (castle.owner == CastleOwner.player && _isFrozenPass) {
      final stage = CastleArtData.stageNumberForLevel(castle.level);
      final candidates = [
        SpriteRegistry.iceCastlePathForStage(stage),
        SpriteRegistry.iceCastlePath,
      ];
      for (final path in candidates) {
        final iceFile = path.replaceFirst('assets/', '');
        try {
          if (!game.images.containsKey(iceFile)) await game.images.load(iceFile);
          fileName = iceFile;
          _usingIceArt = true;
          break;
        } catch (_) {
          // try next candidate
        }
      }
    }

    if (!await _tryLoad(fileName)) {
      if (castle.owner == CastleOwner.player) {
        // No PNG for this level: the game draws the castle itself (unlimited
        // designs, see CastlePainter) instead of leaving it invisible.
        _procedural = true;
        _sprite?.removeFromParent();
        _sprite = null;
        _addLevelBadge();
        _renderedLevel = castle.level;
        return;
      }
      const f = 'kenney/buildings/castle_evil.png';
      if (!await _tryLoad(f)) {
        _renderedLevel = castle.level;
        return;
      }
      fileName = f;
    }

    _sprite?.removeFromParent();
    final sprite = Sprite(game.images.fromCache(fileName));
    _sprite = SpriteComponent(sprite: sprite, size: size);
    add(_sprite!);

    if (castle.owner == CastleOwner.player) _addLevelBadge();
    _renderedLevel = castle.level;
  }

  void _addLevelBadge() {
    _levelBadge?.removeFromParent();
    _levelBadge = TextComponent(
      text: 'Lv ${castle.level}',
      position: Vector2(size.x / 2, size.y + 4),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
    add(_levelBadge!);
  }

  @override
  void render(Canvas canvas) {
    drawGroundShadow(canvas, game, size);
    super.render(canvas);
    if (_procedural) {
      CastlePainter.paint(canvas, Size(size.x, size.y), castle.level,
          ice: _isFrozenPass, time: _time);
      return;
    }
    // Frozen Pass gets a snow-capped castle regardless of which of the 100
    // art designs/levels is currently showing — drawn procedurally on top
    // of whatever sprite is loaded rather than needing a second, chapter-
    // specific art asset per design/stage. Chapter comes from the level the
    // active battle is running (see MapComponent's backgroundTile lookup
    // for the same pattern); Endless mode has no level/chapter, so it never
    // shows here.
    if (castle.owner == CastleOwner.player && _isFrozenPass && !_usingIceArt) {
      _renderSnowCap(canvas);
    }
  }

  Future<bool> _tryLoad(String file) async {
    if (game.images.containsKey(file)) return true;
    try {
      await game.images.load(file);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get _isFrozenPass =>
      game.provider.gameEngine.activeBattle?.level?.chapter == Chapter.frozenPass;

  void _renderSnowCap(Canvas canvas) {
    final w = size.x;
    final capHeight = size.y * 0.16;

    // Jagged snow line sitting along the castle's roofline.
    final snowPaint = Paint()..color = const Color(0xFFF3FAFF).withValues(alpha: 0.92);
    const bumps = 7;
    final snowPath = Path()..moveTo(0, 0);
    for (int i = 0; i <= bumps; i++) {
      final x = w * i / bumps;
      final y = i.isEven ? capHeight : capHeight * 0.25;
      snowPath.lineTo(x, y);
    }
    snowPath.lineTo(w, 0);
    snowPath.close();
    canvas.drawPath(snowPath, snowPaint);

    // A handful of icicles hanging just below the snow line.
    final iciclePaint = Paint()..color = const Color(0xFFCFEFFF).withValues(alpha: 0.85);
    const fracs = [0.14, 0.32, 0.5, 0.68, 0.86];
    for (int i = 0; i < fracs.length; i++) {
      final x = w * fracs[i];
      final len = capHeight * (0.5 + 0.5 * ((i * 37) % 5) / 4);
      final icicle = Path()
        ..moveTo(x - 4, capHeight * 0.7)
        ..lineTo(x + 4, capHeight * 0.7)
        ..lineTo(x, capHeight * 0.7 + len)
        ..close();
      canvas.drawPath(icicle, iciclePaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _healthBar.setPercent(castle.hpPercent);
    if (castle.owner == CastleOwner.player && castle.level != _renderedLevel) {
      _refreshSprite();
    }
  }
}
