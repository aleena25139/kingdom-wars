// Renders a single placed tower and swaps its sprite when Tower.level
// changes (upgrade purchased). No targeting/attack-cooldown logic here —
// BattleEngine decides when the tower fires; this only draws it and, when a
// target is set, a thin aim-line for visual feedback.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/tower_data.dart';
import '../../models/tower.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';
import 'shadow_helper.dart';

class TowerComponent extends PositionComponent {
  final Tower tower;
  final KingdomWarsGame game;

  SpriteComponent? _sprite;
  int _renderedLevel = -1;

  TowerComponent({required this.tower, required this.game})
      : super(size: Vector2.all(56), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = game.worldToScreen(tower.x, tower.y);
    await _refreshSprite();
  }

  Future<void> _refreshSprite() async {
    final def = TowerData.defFor(tower.type);
    final spriteName = def.spriteNameAt(tower.level);
    final assetPath = SpriteRegistry.pathFor(spriteName);
    final fileName = assetPath.replaceFirst('assets/', '');
    if (!game.images.containsKey(fileName)) return;

    _sprite?.removeFromParent();
    _sprite = SpriteComponent(sprite: Sprite(game.images.fromCache(fileName)), size: size);
    add(_sprite!);
    _renderedLevel = tower.level;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (tower.level != _renderedLevel) {
      _refreshSprite();
    }
  }

  @override
  void render(Canvas canvas) {
    drawGroundShadow(canvas, game, size);
    super.render(canvas);
    if (tower.currentTargetEnemyId == null) return;
    // Small level pip so the player can see upgrade level at a glance.
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Lv${tower.level}',
        style: const TextStyle(color: AppColors.textGold, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.x - textPainter.width - 2, 2));
  }
}
