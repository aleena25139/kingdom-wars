// Draws the visual "lane" the battle plays out on (player castle at one end,
// enemies streaming in from the far edge) and a faint grid overlay showing
// valid tower-build slots. Purely decorative/read-only — tap handling for
// placing towers lives in battle_screen.dart, which uses the same
// PathManager math to hit-test.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/game_balance.dart';
import '../../game_logic/path_manager.dart';
import '../kingdom_wars_game.dart';

class PathComponent extends PositionComponent {
  final KingdomWarsGame game;

  PathComponent({required this.game}) : super(priority: -5);

  @override
  void render(Canvas canvas) {
    // Tower grid overlay.
    final gridPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Cell size scales with the current battlefield zoom (pixelsPerUnit)
    // instead of a fixed pixel value, so the grid squares still line up
    // with the lane on screens where the battlefield has been scaled up
    // or down to fill the available space.
    final cellSize = GameBalance.towerGridCellSize * (game.pixelsPerUnit / 48.0);
    for (int col = 0; col < GameBalance.towerGridColumns; col++) {
      for (int row = 0; row < GameBalance.towerGridRows; row++) {
        final (x, y) = PathManager.towerSlotPosition(col, row);
        final screenPos = game.worldToScreen(x, y);
        final rect = Rect.fromCenter(
          center: Offset(screenPos.x, screenPos.y),
          width: cellSize,
          height: cellSize,
        );
        canvas.drawRect(rect, gridPaint);
      }
    }
  }
}
