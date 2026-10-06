// Story mode: 5 chapters (Green Valley, Frozen Pass, Volcanic Ridge,
// Dragon's Lair, Thunderstorm), each with levels 1..infinity. Locked levels show a lock
// icon; unlocked ones show stars earned and can be tapped to start that
// battle. The list only ever shows unlocked levels plus one locked preview
// right after them (see LevelData.visibleLevelsForChapter) — a chapter
// never "runs out" of levels to show.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/level_data.dart';
import '../game_logic/state_provider.dart';
import '../models/level.dart';
import '../services/sound_service.dart';
import 'battle_screen.dart';

class CampaignScreen extends StatelessWidget {
  final Chapter? initialChapter;
  const CampaignScreen({super.key, this.initialChapter});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;

    return Scaffold(
      appBar: AppBar(title: const Text('📜 CAMPAIGN')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: Chapter.values.map((chapter) {
          final levels = LevelData.visibleLevelsForChapter(chapter, progress.unlockedLevelIds);
          return _ChapterSection(
            chapter: chapter,
            levels: levels,
            unlockedIds: progress.unlockedLevelIds,
            starsPerLevel: progress.starsPerLevel,
            initiallyExpanded: initialChapter == null || initialChapter == chapter,
            onLevelTap: (level) {
              SoundService.instance.playButtonTap();
              context.read<StateProvider>().startCampaignLevel(level.id);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BattleScreen()));
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ChapterSection extends StatelessWidget {
  final Chapter chapter;
  final List<LevelDef> levels;
  final Set<int> unlockedIds;
  final Map<int, int> starsPerLevel;
  final bool initiallyExpanded;
  final ValueChanged<LevelDef> onLevelTap;

  const _ChapterSection({
    required this.chapter,
    required this.levels,
    required this.unlockedIds,
    required this.starsPerLevel,
    required this.initiallyExpanded,
    required this.onLevelTap,
  });

  String get _chapterName {
    switch (chapter) {
      case Chapter.greenValley:
        return 'Chapter 1: Green Valley';
      case Chapter.frozenPass:
        return 'Chapter 2: Frozen Pass';
      case Chapter.volcanicRidge:
        return 'Chapter 3: Volcanic Ridge';
      case Chapter.dragonsLair:
        return "Chapter 4: Dragon's Lair";
      case Chapter.thunderstorm:
        return 'Chapter 5: Thunderstorm ⚡🔥 (EXTREME)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.deepPurple,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.royalGold.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: (_) => SoundService.instance.playButtonTap(),
        title: Text(_chapterName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
        children: levels.map((level) {
          final unlocked = unlockedIds.contains(level.id);
          final stars = starsPerLevel[level.id] ?? 0;
          return ListTile(
            enabled: unlocked,
            leading: Icon(
              unlocked ? Icons.play_circle_fill : Icons.lock,
              color: unlocked ? AppColors.emeraldGood : Colors.white38,
            ),
            title: Text(level.name, style: TextStyle(color: unlocked ? AppColors.textPrimary : Colors.white38)),
            trailing: unlocked
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        Icons.star,
                        size: 16,
                        color: i < stars ? AppColors.royalGold : Colors.white24,
                      ),
                    ),
                  )
                : null,
            onTap: unlocked ? () => onLevelTap(level) : null,
          );
        }).toList(),
      ),
    );
  }
}
