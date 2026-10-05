import 'dart:math';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';

/// Full-screen overlay shown when a level is won or lost, with a primary
/// action (Next Level / Play Again / Retry) and a way back to level select.
class WinLoseOverlay extends StatelessWidget {
  final bool won;
  final bool isFinalLevel;
  final VoidCallback onPrimary;
  final VoidCallback onLevelSelect;

  const WinLoseOverlay({
    super.key,
    required this.won,
    required this.isFinalLevel,
    required this.onPrimary,
    required this.onLevelSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = won ? AppColors.gold : AppColors.crimson;
    return Container(
      color: Colors.black.withOpacity(0.75),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (won) SizedBox(width: 280, height: 280, child: CustomPaint(painter: _BurstPainter())),
          Container(
            padding: const EdgeInsets.all(28),
            width: 280,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.royalPurpleDark, AppColors.royalPurple],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: 2),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(won ? Icons.emoji_events : Icons.heart_broken, color: accent, size: 48),
                const SizedBox(height: 12),
                Text(
                  won ? (isFinalLevel ? 'Victory!' : 'Level Complete!') : 'Base Destroyed',
                  style: AppTextStyles.heading.copyWith(color: accent, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? (isFinalLevel ? 'You defended every level of the empire!' : 'On to the next challenge.')
                      : 'Your defenses were overrun.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    SoundService.instance.playButtonTap();
                    onPrimary();
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                  child: Text(won ? (isFinalLevel ? 'Play Again' : 'Next Level') : 'Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    SoundService.instance.playButtonTap();
                    onLevelSelect();
                  },
                  child: const Text('Level Select', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A cheap hand-rolled "confetti burst" -- a ring of small gold dots at
/// fixed angles behind the victory card. No external animation/confetti
/// package required.
class _BurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [AppColors.gold, AppColors.emerald, Colors.white, AppColors.frost];
    const dotCount = 16;
    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi / dotCount) * i;
      final dist = size.width / 2 * (0.6 + 0.4 * (i.isEven ? 1 : 0.7));
      final pos = center + Offset(cos(angle), sin(angle)) * dist;
      canvas.drawCircle(pos, i.isEven ? 4 : 2.5, Paint()..color = colors[i % colors.length].withOpacity(0.8));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => false;
}
