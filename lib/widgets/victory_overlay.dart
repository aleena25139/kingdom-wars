// Shown when BattleEngine.status becomes BattleStatus.victory. Displays
// stars earned (campaign) or wave reached (endless), coin/diamond rewards,
// and lets the player continue to the next level, retry, or go home.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../game_logic/battle_engine.dart';
import '../services/sound_service.dart';

class VictoryOverlay extends StatefulWidget {
  final BattleResult result;
  final bool isEndless;
  final int? nextLevelId;
  final VoidCallback onHome;
  final VoidCallback? onNextLevel;

  /// Opens the Town screen so the player can spend the coins / diamonds just won.
  final VoidCallback? onTown;

  const VictoryOverlay({
    super.key,
    required this.result,
    required this.isEndless,
    this.nextLevelId,
    required this.onHome,
    this.onNextLevel,
    this.onTown,
  });

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> {
  @override
  void initState() {
    super.initState();
    SoundService.instance.playVfx();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isEndless = widget.isEndless;
    final onHome = widget.onHome;
    final onNextLevel = widget.onNextLevel;
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.royalGold, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: AppColors.royalGold, size: 56),
            const SizedBox(height: 8),
            Text('VICTORY!', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
            const SizedBox(height: 16),
            if (!isEndless)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < result.starsEarned;
                  return Icon(
                    Icons.star,
                    size: 36,
                    color: filled ? AppColors.royalGold : Colors.white24,
                  );
                }),
              ),
            const SizedBox(height: 16),
            _RewardRow(icon: Icons.monetization_on, color: AppColors.royalGold, label: '+${result.coinsEarned}'),
            const SizedBox(height: 6),
            _RewardRow(icon: Icons.diamond, color: AppColors.diamondBlue, label: '+${result.diamondsEarned}'),
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
                if (widget.onTown != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      SoundService.instance.playButtonTap();
                      widget.onTown!();
                    },
                    icon: const Icon(Icons.location_city, size: 18),
                    label: const Text('BUILD TOWN'),
                  ),
                ],
                if (!isEndless && onNextLevel != null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      SoundService.instance.playButtonTap();
                      onNextLevel();
                    },
                    child: const Text('NEXT LEVEL'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _RewardRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      ],
    );
  }
}
