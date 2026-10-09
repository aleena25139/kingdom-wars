// Static data table for the 5 campaign chapters. Each chapter's levels are
// NOT a fixed list — they run 1..infinity, generated on demand by byId().
// Difficulty (enemy count + stat scaling) keeps climbing forever with the
// level number, same way the player's castle already scales endlessly (see
// game_balance.dart's castleStatFor comment) — there's no "final level" to
// author, just a formula.
//
// Level ids encode both pieces of information an id needs to carry:
//   id = chapterIndex * _chapterIdSpan + levelNumber   (levelNumber >= 1)
// This keeps ids globally unique across chapters while letting
// state_provider.dart's existing "unlock levelId + 1 on victory" logic work
// completely unchanged — incrementing by 1 just advances to the next level
// number inside the same chapter.
import '../constants/game_balance.dart';
import '../models/enemy.dart';
import '../models/level.dart';
import '../models/wave.dart';

class _ChapterConfig {
  final Chapter chapter;
  final String name;
  final String backgroundTile;
  const _ChapterConfig({
    required this.chapter,
    required this.name,
    required this.backgroundTile,
  });
}

class LevelData {
  LevelData._();

  static const List<_ChapterConfig> _chapters = [
    _ChapterConfig(
      chapter: Chapter.greenValley,
      name: 'Green Valley',
      backgroundTile: 'tile_grass',
    ),
    _ChapterConfig(
      chapter: Chapter.frozenPass,
      name: 'Frozen Pass',
      backgroundTile: 'tile_snow',
    ),
    _ChapterConfig(
      chapter: Chapter.volcanicRidge,
      name: 'Volcanic Ridge',
      backgroundTile: 'tile_lava',
    ),
    _ChapterConfig(
      chapter: Chapter.dragonsLair,
      name: "Dragon's Lair",
      backgroundTile: 'tile_lava',
    ),
    _ChapterConfig(
      chapter: Chapter.thunderstorm,
      name: 'Thunderstorm',
      backgroundTile: 'tile_storm',
    ),
  ];

  static const int _chapterIdSpan = 1000000;

  static int chapterIndexOf(Chapter chapter) => Chapter.values.indexOf(chapter);

  static int idFor(Chapter chapter, int levelNumber) =>
      chapterIndexOf(chapter) * _chapterIdSpan + levelNumber;

  static Chapter _chapterFromId(int id) => _chapters[id ~/ _chapterIdSpan].chapter;

  static int _levelNumberFromId(int id) => id % _chapterIdSpan;

  /// The permanently-unlocked door into every chapter — level 1 of each.
  /// Used to seed a brand-new save (see PlayerProgress) so all 4 chapters
  /// are open from the start even though nothing inside them is cleared yet.
  static List<int> get firstLevelIdsPerChapter =>
      _chapters.map((c) => idFor(c.chapter, 1)).toList();

  /// Builds the fixed 20 waves for one campaign level. Wave 1 is melee
  /// skeletons only (a gentle intro); from wave 2 on, roughly a third of
  /// each wave's spawns are bow-armed skeleton archers mixed in with the
  /// melee ones. Every 5th wave (5/10/15/20) is a tougher "boss wave": more
  /// enemies at a higher stat multiplier, rather than a distinct boss enemy
  /// type. [levelNumber] is 1-based and unbounded within its chapter — both
  /// enemy count and the stat multiplier keep climbing with it forever, the
  /// same way castle stats scale endlessly with castle level.
  static List<Wave> _buildWaves(int levelNumber, int chapterIndex) {
    return _limitBigVillains(_buildWavesRaw(levelNumber, chapterIndex), levelNumber);
  }

  static bool _isBigVillain(EnemyType t) =>
      t == EnemyType.lizard ||
      t == EnemyType.monster ||
      t == EnemyType.blackDragon ||
      t == EnemyType.thunderTitan;

  static EnemyType _smallStandIn(EnemyType t) {
    switch (t) {
      case EnemyType.lizard:
      case EnemyType.monster:
        return EnemyType.goblin;
      case EnemyType.thunderTitan:
        return EnemyType.stormKnight;
      default:
        return EnemyType.skeleton;
    }
  }

  /// Campaign rule: big villains are rare. Every level gets at most ONE black
  /// dragon and ONE lizard (a monster only from level 6 on, one Thunder Titan
  /// only in the storm chapter from level 6 on). Everything else is small.
  /// Only Endless mode brings many big villains (and slowly).
  static List<Wave> _limitBigVillains(List<Wave> waves, int levelNumber) {
    if (waves.isEmpty) return waves;
    final n = waves.length;
    final hadTitan = waves.any((w) => w.spawnEntries.any((e) => e.enemyType == EnemyType.thunderTitan));
    final lizardWave = (n * 0.5).floor().clamp(0, n - 1).toInt();
    final monsterWave = (n * 0.75).floor().clamp(0, n - 1).toInt();
    final lastWave = n - 1;
    final out = <Wave>[];
    for (var wi = 0; wi < n; wi++) {
      final w = waves[wi];
      final entries = <WaveSpawnEntry>[
        for (final e in w.spawnEntries)
          _isBigVillain(e.enemyType)
              ? WaveSpawnEntry(
                  enemyType: _smallStandIn(e.enemyType),
                  delayAfterPreviousSeconds: e.delayAfterPreviousSeconds,
                )
              : e,
      ];
      void swapIn(EnemyType t) {
        if (entries.isEmpty) {
          entries.add(WaveSpawnEntry(enemyType: t, delayAfterPreviousSeconds: 0));
          return;
        }
        final i = entries.length ~/ 2;
        entries[i] = WaveSpawnEntry(
          enemyType: t,
          delayAfterPreviousSeconds: entries[i].delayAfterPreviousSeconds,
        );
      }

      if (wi == lizardWave) swapIn(EnemyType.lizard);
      if (wi == monsterWave && levelNumber >= 6) swapIn(EnemyType.monster);
      if (wi == lastWave) {
        entries.add(WaveSpawnEntry(enemyType: EnemyType.blackDragon, delayAfterPreviousSeconds: 3.0));
        if (hadTitan && levelNumber >= 6) {
          entries.add(WaveSpawnEntry(enemyType: EnemyType.thunderTitan, delayAfterPreviousSeconds: 3.0));
        }
      }
      out.add(Wave(
        waveNumber: w.waveNumber,
        spawnEntries: entries,
        isBossWave: w.isBossWave,
        statMultiplier: w.statMultiplier,
      ));
    }
    return out;
  }

  static List<Wave> _buildWavesRaw(int levelNumber, int chapterIndex) {
    if (_chapters[chapterIndex].chapter == Chapter.thunderstorm) {
      return _buildStormWaves(levelNumber);
    }
    if (_chapters[chapterIndex].chapter == Chapter.greenValley && levelNumber <= _earlyLevels) {
      return _buildEarlyWaves(levelNumber);
    }
    final levelIndexInChapter = levelNumber - 1; // 0-based, no upper bound
    final waves = <Wave>[];
    for (int waveNum = 1; waveNum <= GameBalance.totalWavesPerLevel; waveNum++) {
      final isBossWave = waveNum % GameBalance.bossWaveInterval == 0;
      // Difficulty climbs on three axes now, not just two: how far through
      // this level's 20 waves we are, how deep into the current chapter we
      // are (levelIndexInChapter), and — new — which chapter this is at
      // all. That last term (chapterBonus) is what makes Frozen Pass /
      // Volcanic Ridge / Dragon's Lair enemies noticeably tougher than
      // Green Valley's even at each chapter's own level 1, on top of each
      // chapter still climbing further as its levels progress.
      final chapterBonus = chapterIndex * 0.4;
      final difficultyScale = 1.0 +
          chapterBonus +
          (levelIndexInChapter * 0.10) +
          (waveNum / GameBalance.totalWavesPerLevel) * 0.5;

      final baseCount = 4 + levelIndexInChapter + (waveNum ~/ 4);
      final enemyCount = isBossWave ? baseCount + 6 : baseCount;
      final statMultiplier = isBossWave ? difficultyScale * 1.6 : difficultyScale;

      // Boss waves also bring black (bad) dragons: 1 on wave 5, 2 on waves
      // 10 and 15, 3 on wave 20 ... they fly in at the end of the wave.
      final int blackDragons = isBossWave ? 1 + waveNum ~/ 10 : 0;
      final entries = List<WaveSpawnEntry>.generate(enemyCount + blackDragons, (i) {
        return WaveSpawnEntry(
          enemyType: i >= enemyCount ? EnemyType.blackDragon : _enemyTypeForSpawn(waveNum, i),
          delayAfterPreviousSeconds: i == 0 ? 0 : (i == enemyCount ? 2.5 : (i > enemyCount ? 3.0 : 0.8)),
        );
      });

      waves.add(Wave(
        waveNumber: waveNum,
        isBossWave: isBossWave,
        statMultiplier: statMultiplier,
        spawnEntries: entries,
      ));
    }
    return waves;
  }

  // ---------------------------------------------------------------------
  // GENTLE START: the first few Green Valley levels are meant for learning.
  //  * Fewer waves (8 on level 1, then +3 per level up to the usual 20).
  //  * Only a handful of enemies per wave, spread out with longer gaps.
  //  * Enemy types are introduced slowly: skeletons first, then archers,
  //    goblins, lizards - Monsters and black dragons only show up later.
  //  * Enemy stats start well below 1.0x and climb gently.
  // From level 6 on the normal formula below takes over.
  // ---------------------------------------------------------------------
  static const int _earlyLevels = 5;

  static List<Wave> _buildEarlyWaves(int levelNumber) {
    final levelIdx = levelNumber - 1; // 0..4
    final totalWaves = (8 + levelIdx * 3).clamp(8, GameBalance.totalWavesPerLevel).toInt();
    final waves = <Wave>[];
    for (int waveNum = 1; waveNum <= totalWaves; waveNum++) {
      final isBossWave = waveNum % GameBalance.bossWaveInterval == 0;
      final progress = waveNum / totalWaves;
      final difficultyScale = 0.55 + levelIdx * 0.12 + progress * 0.35;
      final baseCount = 2 + levelIdx + waveNum ~/ 3;
      final bossExtra = isBossWave ? (levelIdx < 2 ? 1 : 3) : 0;
      // the first black dragon waits until level 3
      final blackDragons = (isBossWave && levelIdx >= 2) ? 1 : 0;
      final types = <EnemyType>[
        for (int i = 0; i < baseCount + bossExtra; i++) _earlyEnemyForSpawn(waveNum, i, levelIdx),
        for (int i = 0; i < blackDragons; i++) EnemyType.blackDragon,
      ];
      final entries = List<WaveSpawnEntry>.generate(types.length, (i) {
        return WaveSpawnEntry(
          enemyType: types[i],
          delayAfterPreviousSeconds: i == 0 ? 0 : (types[i] == EnemyType.blackDragon ? 3.0 : 1.6),
        );
      });
      waves.add(Wave(
        waveNumber: waveNum,
        isBossWave: isBossWave,
        statMultiplier: isBossWave ? difficultyScale * 1.25 : difficultyScale,
        spawnEntries: entries,
      ));
    }
    return waves;
  }

  static EnemyType _earlyEnemyForSpawn(int waveNum, int i, int levelIdx) {
    switch (i % 4) {
      case 1:
        return waveNum >= 4 ? EnemyType.goblin : EnemyType.skeleton;
      case 2:
        return waveNum >= 3 ? EnemyType.skeletonArcher : EnemyType.skeleton;
      case 3:
        if (waveNum >= 10 && levelIdx >= 2) return EnemyType.monster;
        return waveNum >= 6 ? EnemyType.lizard : EnemyType.skeleton;
      default:
        return EnemyType.skeleton;
    }
  }

  // ---------------------------------------------------------------------
  // THUNDERSTORM chapter: deliberately brutal.
  //  * Far MORE waves than other chapters, and every level has more waves
  //    than the one before it: 30, 36, 42, ... (capped at 100).
  //  * Much bigger waves (10+ enemies from wave 1) that keep growing with
  //    both the wave number and the level number.
  //  * Everything hits harder: base stat multiplier starts at 2.5x (Dragon's
  //    Lair level 1 is ~2.2x) and climbs each wave and each level.
  //  * Old enemies (skeleton / archer / lizard / monster) show up too, but
  //    they are joined by the four storm-only enemies (Ember Hound, Storm
  //    Knight, Storm Caller, and the Thunder Titan on boss waves).
  // ---------------------------------------------------------------------
  static const int _stormBaseWaves = 30;
  static const int _stormExtraWavesPerLevel = 6;
  static const int _stormMaxWaves = 100;

  static List<Wave> _buildStormWaves(int levelNumber) {
    final levelIdx = levelNumber - 1;
    final totalWaves =
        (_stormBaseWaves + _stormExtraWavesPerLevel * levelIdx).clamp(_stormBaseWaves, _stormMaxWaves).toInt();
    final double spawnDelay = (0.6 - levelIdx * 0.02).clamp(0.35, 0.6).toDouble();
    final waves = <Wave>[];
    for (int waveNum = 1; waveNum <= totalWaves; waveNum++) {
      final isBossWave = waveNum % GameBalance.bossWaveInterval == 0;
      final difficultyScale = 2.5 + levelIdx * 0.25 + (waveNum / totalWaves) * 1.5;
      final int baseCount = (10 + levelIdx * 2 + waveNum ~/ 2).clamp(10, 80).toInt();
      final bossExtra = isBossWave ? 6 : 0;
      final types = <EnemyType>[
        for (int i = 0; i < baseCount; i++) _stormEnemyForSpawn(waveNum, i),
      ];
      if (isBossWave) {
        final int titans = (1 + waveNum ~/ 15 + levelIdx ~/ 3).clamp(1, 6).toInt();
        final int dragons = (1 + waveNum ~/ 12).clamp(1, 4).toInt();
        for (int i = 0; i < bossExtra; i++) {
          types.add(i < titans ? EnemyType.thunderTitan : EnemyType.stormKnight);
        }
        for (int i = 0; i < dragons; i++) {
          types.add(EnemyType.blackDragon);
        }
      }
      final entries = List<WaveSpawnEntry>.generate(types.length, (i) {
        return WaveSpawnEntry(
          enemyType: types[i],
          delayAfterPreviousSeconds: i == 0 ? 0 : spawnDelay,
        );
      });
      waves.add(Wave(
        waveNumber: waveNum,
        isBossWave: isBossWave,
        statMultiplier: isBossWave ? difficultyScale * 1.5 : difficultyScale,
        spawnEntries: entries,
      ));
    }
    return waves;
  }

  /// 10-slot pattern for the storm chapter. New enemy kinds are introduced
  /// as waves progress; until a kind is unlocked its slot falls back to a
  /// cheaper enemy.
  static EnemyType _stormEnemyForSpawn(int waveNum, int i) {
    switch (i % 10) {
      case 1:
      case 6:
      case 9:
        return EnemyType.emberHound;
      case 2:
        return EnemyType.skeletonArcher;
      case 3:
        return waveNum >= 3 ? EnemyType.lizard : EnemyType.emberHound;
      case 5:
        return waveNum >= 5 ? EnemyType.stormKnight : EnemyType.skeleton;
      case 7:
        return waveNum >= 6 ? EnemyType.stormCaller : EnemyType.skeletonArcher;
      case 8:
        return EnemyType.monster; // TEST: from wave 1 (orig: wave >= 4)
      case 4:
        return EnemyType.goblin;
      default:
        return EnemyType.skeleton;
    }
  }

  /// Wave 1 stays melee skeletons only (a gentle intro). From wave 2 on,
  /// spawns cycle through a fixed 5-slot pattern — skeleton, skeleton,
  /// skeleton archer, Lizard, Monster — so every wave gets a mix of a fast
  /// skirmisher and a slow tank alongside the original skeleton roster.
  /// Monster is held back until wave 4+ (it's meant to feel like a real
  /// commitment of the player's attention, not something wave 2 drowns you
  /// in) and falls back to another skeleton before then.
  static EnemyType _enemyTypeForSpawn(int waveNum, int i) {
    // TEST: the Monster used to be locked behind wave 4 AND only landed in
    // slot 4, which doesn't exist in waves 1-3 (they only have 4 enemies), so
    // it effectively never showed up. Now wave 1 ends with one Monster, and
    // from wave 2 on slot 1 is always a Monster.
    if (waveNum == 1) {
      if (i == 3) return EnemyType.monster;
      return i == 2 ? EnemyType.goblin : EnemyType.skeleton; // first goblin shows up in wave 1
    }
    switch (i % 5) {
      case 1:
        return EnemyType.monster;
      case 2:
        return EnemyType.skeletonArcher;
      case 3:
        return EnemyType.lizard;
      case 4:
        return EnemyType.goblin; // goblin packs from wave 2 on
      default:
        return EnemyType.skeleton;
    }
  }

  /// Generates one level's full definition on demand. There's no backing
  /// list to look up — any (chapter, levelNumber >= 1) combination is valid
  /// and produces a level, which is what makes chapters endless.
  static LevelDef byId(int id) {
    final chapter = _chapterFromId(id);
    final levelNumber = _levelNumberFromId(id);
    final chapterIndex = chapterIndexOf(chapter);
    final chapterConfig = _chapters[chapterIndex];
    return LevelDef(
      id: id,
      chapter: chapter,
      name: '${chapterConfig.name} $levelNumber',
      backgroundTile: chapterConfig.backgroundTile,
      waves: _buildWaves(levelNumber, chapterIndex),
      coinReward: chapter == Chapter.thunderstorm
          ? 400 + levelNumber * 60
          : 100 + levelNumber * 25,
      diamondReward: chapter == Chapter.thunderstorm
          ? 15 + (levelNumber ~/ 3) * 10
          : 5 + (levelNumber ~/ 5) * 10,
      starThresholds: 60, // >=60% castle HP remaining at victory = 3 stars (used by battle_engine)
    );
  }

  /// Highest level number unlocked so far in [chapter] (0 if not even level
  /// 1 is marked unlocked yet, which shouldn't normally happen). Assumes
  /// unlocks are contiguous from level 1, which they always are given
  /// state_provider.dart only ever unlocks "current + 1" on victory.
  static int highestUnlockedLevelNumber(Chapter chapter, Set<int> unlockedIds) {
    var highest = 0;
    for (var n = 1; unlockedIds.contains(idFor(chapter, n)); n++) {
      highest = n;
    }
    return highest;
  }

  /// For UI lists only (CampaignScreen) — a chapter's levels never actually
  /// run out, so this returns every unlocked level plus [previewCount] more
  /// locked ones right after (shown with a lock icon), keeping the on-screen
  /// list finite without ever making the chapter look "finished."
  static List<LevelDef> visibleLevelsForChapter(
    Chapter chapter,
    Set<int> unlockedIds, {
    int previewCount = 1,
  }) {
    final highestUnlocked = highestUnlockedLevelNumber(chapter, unlockedIds);
    final lastNumberToShow = (highestUnlocked == 0 ? 1 : highestUnlocked) + previewCount;
    return List<LevelDef>.generate(
      lastNumberToShow,
      (i) => byId(idFor(chapter, i + 1)),
    );
  }

  /// Sum, across all 5 chapters, of how many levels are currently unlocked.
  /// Used only to give the leaderboard a meaningful "out of" denominator for
  /// stars now that there's no fixed total level count.
  static int totalUnlockedLevelsCount(Set<int> unlockedIds) {
    var total = 0;
    for (final cfg in _chapters) {
      total += highestUnlockedLevelNumber(cfg.chapter, unlockedIds);
    }
    return total;
  }
}
