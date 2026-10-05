// Static definition of one campaign level. The actual Wave list for a level
// is supplied by level_data.dart (STEP 2) and referenced here by id lookup
// to keep this file free of the large data table.
import 'wave.dart';

// thunderstorm is appended LAST on purpose: level ids are chapterIndex-based,
// so existing chapters/saves keep their ids.
enum Chapter { greenValley, frozenPass, volcanicRidge, dragonsLair, thunderstorm }

class LevelDef {
  final int id; // chapterIndex * 1_000_000 + levelNumber (see LevelData) — unbounded
  final Chapter chapter;
  final String name;
  final String backgroundTile; // sprite registry key, e.g. 'tile_grass'
  final List<Wave> waves;
  final int coinReward;
  final int diamondReward;
  final int starThresholds; // castle HP % remaining needed for 3-star, etc.

  const LevelDef({
    required this.id,
    required this.chapter,
    required this.name,
    required this.backgroundTile,
    required this.waves,
    required this.coinReward,
    required this.diamondReward,
    this.starThresholds = 0,
  });
}
