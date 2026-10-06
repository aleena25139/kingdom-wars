// The "⚔ BATTLE" destination from the main menu: a visual overview of the
// 4 campaign chapters (as map nodes connected by a path) plus a quick jump
// into Endless mode. Tapping a chapter node opens CampaignScreen scrolled to
// that chapter's levels (each chapter runs 1..infinity — see LevelData).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/level_data.dart';
import '../game_logic/state_provider.dart';
import '../models/level.dart';
import '../services/sound_service.dart';
import 'battle_screen.dart';
import 'campaign_screen.dart';

class BattleMapScreen extends StatelessWidget {
  const BattleMapScreen({super.key});

  static const _chapterMeta = {
    Chapter.greenValley: (name: 'Green Valley', icon: Icons.park, color: AppColors.emeraldGood),
    Chapter.frozenPass: (name: 'Frozen Pass', icon: Icons.ac_unit, color: AppColors.diamondBlue),
    Chapter.volcanicRidge: (name: 'Volcanic Ridge', icon: Icons.whatshot, color: AppColors.orange),
    Chapter.dragonsLair: (name: "Dragon's Lair", icon: Icons.castle, color: AppColors.crimsonEvil),
    Chapter.thunderstorm: (name: 'Thunderstorm ⚡ EXTREME', icon: Icons.thunderstorm, color: Color(0xFFB388FF)),
  };

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;

    return Scaffold(
      appBar: AppBar(title: const Text('⚔ BATTLE MAP')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final chapter in Chapter.values) ...[
            _ChapterNode(
              chapter: chapter,
              meta: _chapterMeta[chapter]!,
              levelsUnlocked: LevelData.highestUnlockedLevelNumber(chapter, progress.unlockedLevelIds),
              onTap: () {
                SoundService.instance.playButtonTap();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CampaignScreen(initialChapter: chapter)),
                );
              },
            ),
            if (chapter != Chapter.thunderstorm)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Icon(Icons.more_vert, color: AppColors.royalGold),
              ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              SoundService.instance.playButtonTap();
              context.read<StateProvider>().startEndless();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BattleScreen()));
            },
            icon: const Icon(Icons.all_inclusive),
            label: const Text('JUMP TO ENDLESS'),
          ),
        ],
      ),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  final Chapter chapter;
  final ({String name, IconData icon, Color color}) meta;
  final int levelsUnlocked;
  final VoidCallback onTap;

  const _ChapterNode({
    required this.chapter,
    required this.meta,
    required this.levelsUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: meta.color.withValues(alpha: 0.7), width: 2),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundColor: meta.color.withValues(alpha: 0.2), child: Icon(meta.icon, color: meta.color, size: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Level $levelsUnlocked unlocked', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.royalGold),
          ],
        ),
      ),
    );
  }
}
