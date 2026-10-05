// Shown when BattleEngine.status becomes BattleStatus.defeat (player castle
// HP reached 0). Offers a retry (restarts the same level/endless run) or a
// way back to the main menu.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/sound_service.dart';

class DefeatOverlay extends StatefulWidget {
  final VoidCallback onHome;
  final VoidCallback onRetry;

  /// True when the battle was lost because the castle's MP ran out.
  final bool byMp;

  /// Endless runs: score, wave reached, kills and whether it is a new best
  /// (null score = not an Endless run).
  final int? endlessScore;
  final int endlessWave;
  final int endlessKills;
  final bool newBest;
  final int bestScore;

  const DefeatOverlay({
    super.key,
    required this.onHome,
    required this.onRetry,
    this.byMp = false,
    this.endlessScore,
    this.endlessWave = 0,
    this.endlessKills = 0,
    this.newBest = false,
    this.bestScore = 0,
  });

  @override
  State<DefeatOverlay> createState() => _DefeatOverlayState();
}

class _DefeatOverlayState extends State<DefeatOverlay> {
  @override
  void initState() {
    super.initState();
    SoundService.instance.playVfx();
  }

  @override
  Widget build(BuildContext context) {
    final onHome = widget.onHome;
    final onRetry = widget.onRetry;
    final byMp = widget.byMp;
    final endlessScore = widget.endlessScore;
    final endlessWave = widget.endlessWave;
    final endlessKills = widget.endlessKills;
    final newBest = widget.newBest;
    final bestScore = widget.bestScore;
    return Container(
      color: Colors.black.withOpacity(0.8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.crimsonEvil, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(byMp ? Icons.battery_alert : Icons.heart_broken, color: AppColors.crimsonEvil, size: 56),
            const SizedBox(height: 8),
            Text(
              'DEFEAT',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.crimsonEvil,
                    fontSize: 32,
                    shadows: [Shadow(color: AppColors.crimsonEvil.withOpacity(0.6), blurRadius: 16)],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              byMp
                  ? 'Your MP ran out! Charge your troops carefully and try again!'
                  : 'Your castle has fallen. Rally your army and try again!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            if (endlessScore != null) ...[
              const SizedBox(height: 14),
              Text(
                '🏆 SCORE  $endlessScore',
                style: const TextStyle(color: AppColors.lightGold, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                newBest ? '🎉 NEW BEST SCORE!' : 'Best: $bestScore',
                style: TextStyle(
                  color: newBest ? AppColors.royalGold : AppColors.textPrimary.withOpacity(0.7),
                  fontWeight: newBest ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Wave $endlessWave  •  $endlessKills enemies defeated',
                style: TextStyle(color: AppColors.textPrimary.withOpacity(0.7), fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    SoundService.instance.playButtonTap();
                    onHome();
                  },
                  child: const Text('HOME'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    SoundService.instance.playButtonTap();
                    onRetry();
                  },
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
