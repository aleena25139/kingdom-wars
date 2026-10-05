// Small reusable health bar. Every render component that has HP (units,
// enemies, castles) owns one of these and calls setPercent() each frame —
// it never reads game_logic models itself, keeping it a pure render widget.
// Pass showsHpText: true (used for the player's archers) to also draw the
// current HP number centered on the bar.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class HealthBarComponent extends PositionComponent {
  double _percent = 1.0;
  int _currentHp = 0;
  Color foregroundColor;
  final bool showsHpText;

  HealthBarComponent({
    required Vector2 size,
    required Vector2 position,
    this.foregroundColor = AppColors.emeraldGood,
    this.showsHpText = false,
  }) : super(size: size, position: position, anchor: Anchor.center);

  void setPercent(double percent) {
    _percent = percent.clamp(0.0, 1.0);
  }

  /// Sets the bar from raw hp/maxHp — use this instead of setPercent() when
  /// showsHpText is true, so the drawn number stays in sync with the bar.
  void setHp(int currentHp, int maxHp) {
    _currentHp = currentHp;
    setPercent(maxHp == 0 ? 0 : currentHp / maxHp);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final backgroundPaint = Paint()..color = Colors.black54;
    final foregroundPaint = Paint()..color = _colorForPercent();
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * _percent, size.y), foregroundPaint);
    canvas.drawRect(rect, borderPaint);

    if (showsHpText) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$_currentHp',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
      );
    }
  }

  Color _colorForPercent() {
    if (_percent > 0.5) return foregroundColor;
    if (_percent > 0.2) return AppColors.orange;
    return AppColors.crimsonEvil;
  }
}
