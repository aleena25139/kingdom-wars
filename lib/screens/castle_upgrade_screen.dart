// Shows the player's castle at its current level with 3 stat cards (HP,
// spawn rate, effective army size) and an upgrade button. Progression is
// endless (Grow-Castle style) — there's no max level, the button just keeps
// showing the next level's cost forever, computed from GameBalance.castleStatFor.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/castle_art_data.dart';
import '../constants/game_balance.dart';
import '../game_logic/state_provider.dart';
import '../services/castle_painter.dart';
import '../services/sound_service.dart';
import '../services/sprite_registry.dart';
import '../widgets/top_hud_bar.dart';

class CastleUpgradeScreen extends StatelessWidget {
  const CastleUpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final progress = provider.progress;
    final currentStat = GameBalance.castleStatFor(progress.castleLevel);
    final nextStat = GameBalance.castleStatFor(progress.castleLevel + 1);
    final castleNumber = CastleArtData.castleNumberForLevel(progress.castleLevel);
    final stageNumber = CastleArtData.stageNumberForLevel(progress.castleLevel);
    final castleImagePath = SpriteRegistry.pathForCastle(castleNumber, stageNumber);

    return Scaffold(
      appBar: AppBar(title: const Text('🏰 CASTLE')),
      body: Column(
        children: [
          const TopHudBar(),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: 140,
            child: Image.asset(
              castleImagePath,
              fit: BoxFit.contain,
              // No castle_N_stage_N.png shipped for this level -> the game draws
              // the castle itself (CastlePainter), so there's always art.
              errorBuilder: (_, __, ___) => CustomPaint(
                size: const Size(140, 140),
                painter: _GeneratedCastlePainter(progress.castleLevel),
              ),
            ),
          ),
          Text('Castle Level ${progress.castleLevel}', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Design #$castleNumber • Stage $stageNumber/${CastleArtData.stagesPerCastle}',
            style: const TextStyle(color: AppColors.cyan, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _StatCard(label: 'HP', value: '${currentStat.hp}', nextValue: '${nextStat.hp}')),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: '🔵 Max MP',
                    value: '${GameBalance.maxMpFor(progress.castleLevel)}',
                    nextValue: '${GameBalance.maxMpFor(progress.castleLevel + 1)}  (+${GameBalance.mpBonusForLevel(progress.castleLevel + 1)})',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Army Size', value: '${progress.castleLevel + 2}', nextValue: '${progress.castleLevel + 3}')),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  SoundService.instance.playButtonTap();
                  final ok = provider.upgradeCastle();
                  if (ok) {
                    SoundService.instance.playVfx();
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not enough coins!')),
                    );
                  }
                },
                child: Text('UPGRADE — ${nextStat.upgradeCost} coins'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? nextValue;

  const _StatCard({required this.label, required this.value, this.nextValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.cyan, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold, fontSize: 18)),
          if (nextValue != null) ...[
            const SizedBox(height: 2),
            Text('→ $nextValue', style: const TextStyle(color: AppColors.emeraldGood, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}


class _GeneratedCastlePainter extends CustomPainter {
  final int level;
  const _GeneratedCastlePainter(this.level);

  @override
  void paint(Canvas canvas, Size size) => CastlePainter.paint(canvas, size, level);

  @override
  bool shouldRepaint(covariant _GeneratedCastlePainter old) => old.level != level;
}
