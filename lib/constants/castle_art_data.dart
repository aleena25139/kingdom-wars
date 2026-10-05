// Maps the player's endless castle level to a specific piece of art out of
// a 100-design x 7-stage roster (700 images total). Every 7 upgrades
// completes one castle design and moves on to the next; after all 100
// designs are used the cycle repeats from design #1 again (the level number
// itself keeps climbing forever — only the art loops).
//
// Expected asset files (place these under
// assets/kenney/buildings/castles/ and add that folder to pubspec.yaml's
// `flutter: assets:` list):
//   castle_1_stage_1.png ... castle_1_stage_7.png
//   castle_2_stage_1.png ... castle_2_stage_7.png
//   ...
//   castle_100_stage_1.png ... castle_100_stage_7.png
class CastleArtData {
  CastleArtData._();

  static const int totalCastleDesigns = 100;
  static const int stagesPerCastle = 7;
  static const int levelsPerCycle = totalCastleDesigns * stagesPerCastle; // 700

  /// Which castle design (1..100) is shown at [level].
  static int castleNumberForLevel(int level) => _stageIndex(level) ~/ stagesPerCastle + 1;

  /// Which build stage (1..7) of that castle design is shown at [level].
  static int stageNumberForLevel(int level) => _stageIndex(level) % stagesPerCastle + 1;

  /// Absolute, never-looping design number (0-based). The procedural
  /// CastlePainter seeds from this, so generated castles never repeat even
  /// after level 700 (PNG art loops, generated art doesn't).
  static int designIndexForLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return (safeLevel - 1) ~/ stagesPerCastle;
  }

  static int _stageIndex(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return (safeLevel - 1) % levelsPerCycle;
  }

  /// Logical sprite name for [level], e.g. "castle_37_stage_4". Register
  /// this pattern's asset path via SpriteRegistry.pathForCastle().
  static String spriteNameForLevel(int level) =>
      'castle_${castleNumberForLevel(level)}_stage_${stageNumberForLevel(level)}';
}
