// Everything that gets persisted to shared_preferences via save_service.
// Plain data class with toJson/fromJson so SaveService can serialize it
// without any Flutter/Flame dependency.
import '../constants/game_balance.dart';
import '../constants/town_data.dart';
import '../constants/level_data.dart';
import '../constants/unit_data.dart';
import '../models/unit.dart';

enum Difficulty { easy, normal, hard }

enum AppLanguage { english, urdu, hindi }

class PlayerProgress {
  int coins;
  int diamonds;
  int castleLevel;
  int playerLevel; // overall account/XP level shown on main menu
  Set<int> unlockedLevelIds;
  Map<int, int> starsPerLevel; // levelId -> stars earned (0-3)
  int highestEndlessWave;
  int highestEndlessScore; // best Endless score (kills + waves)
  String playerName; // shown on the global leaderboard ('' = auto name)

  /// Army units the player has permanently unlocked (one-time coins/diamonds
  /// spend from the Army screen). Archer is unlocked from the start.
  Set<UnitType> unlockedUnitTypes;

  /// Permanent level (1-3) per unlocked unit type, upgraded from the Army
  /// screen with coins — mirrors castleLevel but per unit type. Absent key
  /// == not unlocked yet.
  Map<UnitType, int> unitLevels;

  /// Per-slot level for the player's Knight squad (see UnitData's "Knight
  /// squad slots" doc). Always length UnitData.knightMaxSlots; 0 in a slot
  /// means that slot hasn't been purchased yet. Knight is deliberately kept
  /// out of [unlockedUnitTypes]/[unitLevels] above — use [anyKnightUnlocked]
  /// / [unlockedKnightCount] instead of checking those two for Knight.
  List<int> knightSlotLevels;

  /// Where the player put each soldier on the battlefield grid (see
  /// ArmyManager): "<unitType>#<n>" -> col*10+row. Empty = default layout.
  Map<String, int> formation;

  DateTime? lastFreeChestOpenedAt;
  DateTime? nextFreeChestReadyAt;

  // ---- Town module (see constants/town_data.dart) ----
  /// What is built where: key = TownData.key(col,row) -> building id.
  /// The map is endless, so (col,row) can be negative.
  Map<int, String> townGrid;

  /// Highest town level whose diamond reward was already paid out.
  int townLevelClaimed;

  /// Number of campaign levels beaten (drives which buildings are unlocked).
  int get levelsWon => starsPerLevel.values.where((s) => s > 0).length;

  bool get anyKnightUnlocked => knightSlotLevels.any((lvl) => lvl > 0);
  int get unlockedKnightCount => knightSlotLevels.where((lvl) => lvl > 0).length;

  // Settings
  bool musicEnabled;
  bool sfxEnabled;
  bool vibrationEnabled;
  AppLanguage language;
  Difficulty difficulty;

  PlayerProgress({
    this.coins = GameBalance.startingCoins,
    this.diamonds = GameBalance.startingDiamonds,
    this.castleLevel = 1,
    this.playerLevel = 1,
    Set<int>? unlockedLevelIds,
    Map<int, int>? starsPerLevel,
    this.highestEndlessWave = 0,
    this.highestEndlessScore = 0,
    this.playerName = '',
    Set<UnitType>? unlockedUnitTypes,
    Map<UnitType, int>? unitLevels,
    List<int>? knightSlotLevels,
    Map<String, int>? formation,
    this.lastFreeChestOpenedAt,
    this.nextFreeChestReadyAt,
    Map<int, String>? townGrid,
    this.townLevelClaimed = 0,
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.vibrationEnabled = true,
    this.language = AppLanguage.english,
    this.difficulty = Difficulty.normal,
  })  : unlockedLevelIds = unlockedLevelIds ?? LevelData.firstLevelIdsPerChapter.toSet(),
        starsPerLevel = starsPerLevel ?? {},
        unlockedUnitTypes = unlockedUnitTypes ?? {UnitType.archer},
        unitLevels = unitLevels ?? {UnitType.archer: 1},
        knightSlotLevels = knightSlotLevels ?? List<int>.filled(UnitData.knightMaxSlots, 0),
        formation = formation ?? {},
        townGrid = townGrid ?? {};

  /// Old saves (and cloud saves) still say 'paladin' / 'cleric': they are now
  /// the Elf Prince and the Magician, with the same progress. Unknown names
  /// are ignored instead of crashing the load.
  static UnitType? _unitTypeFromSaved(String name) {
    switch (name) {
      case 'paladin':
        return UnitType.elfPrince;
      case 'cleric':
        return UnitType.magician;
    }
    for (final t in UnitType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  static String _migrateFormationKey(String key) {
    if (key.startsWith('paladin#')) return key.replaceFirst('paladin#', 'elfPrince#');
    if (key.startsWith('cleric#')) return key.replaceFirst('cleric#', 'magician#');
    return key;
  }

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    return PlayerProgress(
      // Old saves had Bricks for the town: they are turned into coins once.
      coins: (json['coins'] ?? GameBalance.startingCoins) + (((json['bricks'] ?? 0) as int) * TownData.coinsPerOldBrick),
      diamonds: json['diamonds'] ?? GameBalance.startingDiamonds,
      castleLevel: json['castleLevel'] ?? 1,
      playerLevel: json['playerLevel'] ?? 1,
      // Always merge in every chapter's level 1 so saves made before a new
      // chapter existed (e.g. Thunderstorm) still get its door unlocked.
      unlockedLevelIds: <int>{
        ...LevelData.firstLevelIdsPerChapter,
        ...((json['unlockedLevelIds'] as List?)?.map((e) => e as int) ?? const <int>[]),
      },
      starsPerLevel: (json['starsPerLevel'] as Map?)?.map(
            (k, v) => MapEntry(int.parse(k.toString()), v as int),
          ) ??
          {},
      highestEndlessWave: json['highestEndlessWave'] ?? 0,
      highestEndlessScore: json['highestEndlessScore'] ?? 0,
      playerName: (json['playerName'] ?? '').toString(),
      unlockedUnitTypes: (json['unlockedUnitTypes'] as List?)
              ?.map((e) => _unitTypeFromSaved(e.toString()))
              .whereType<UnitType>()
              .toSet() ??
          {UnitType.archer},
      unitLevels: (json['unitLevels'] as Map?)
              ?.map((k, v) => MapEntry(_unitTypeFromSaved(k.toString()), v as int))
              .entries
              .where((e) => e.key != null)
              .fold<Map<UnitType, int>>({}, (m, e) => m..[e.key!] = e.value) ??
          {UnitType.archer: 1},
      knightSlotLevels: _normalizeKnightSlots(
          (json['knightSlotLevels'] as List?)?.map((e) => e as int).toList()),
      formation: (json['formation'] as Map?)?.map(
            (k, v) => MapEntry(_migrateFormationKey(k.toString()), v as int),
          ) ??
          {},
      lastFreeChestOpenedAt: json['lastFreeChestOpenedAt'] != null
          ? DateTime.tryParse(json['lastFreeChestOpenedAt'])
          : null,
      nextFreeChestReadyAt: json['nextFreeChestReadyAt'] != null
          ? DateTime.tryParse(json['nextFreeChestReadyAt'])
          : null,
      townGrid: TownData.migrateGrid(
        (json['townGrid'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k.toString()), v.toString()),
            ) ??
            <int, String>{},
      ),
      townLevelClaimed: json['townLevelClaimed'] ?? 0,
      musicEnabled: json['musicEnabled'] ?? true,
      sfxEnabled: json['sfxEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      language: AppLanguage.values[json['language'] ?? 0],
      difficulty: Difficulty.values[json['difficulty'] ?? 1],
    );
  }

  /// Pads/truncates a saved knightSlotLevels list to exactly
  /// UnitData.knightMaxSlots entries, so an old save (or a future change to
  /// knightMaxSlots) never crashes on a length mismatch.
  static List<int> _normalizeKnightSlots(List<int>? saved) {
    final result = List<int>.filled(UnitData.knightMaxSlots, 0);
    if (saved == null) return result;
    for (var i = 0; i < result.length && i < saved.length; i++) {
      result[i] = saved[i];
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'diamonds': diamonds,
        'castleLevel': castleLevel,
        'playerLevel': playerLevel,
        'unlockedLevelIds': unlockedLevelIds.toList(),
        'starsPerLevel':
            starsPerLevel.map((k, v) => MapEntry(k.toString(), v)),
        'highestEndlessWave': highestEndlessWave,
        'highestEndlessScore': highestEndlessScore,
        'playerName': playerName,
        'unlockedUnitTypes': unlockedUnitTypes.map((t) => t.name).toList(),
        'unitLevels': unitLevels.map((k, v) => MapEntry(k.name, v)),
        'knightSlotLevels': knightSlotLevels,
        'formation': formation,
        'lastFreeChestOpenedAt': lastFreeChestOpenedAt?.toIso8601String(),
        'nextFreeChestReadyAt': nextFreeChestReadyAt?.toIso8601String(),
        'townGrid': townGrid.map((k, v) => MapEntry(k.toString(), v)),
        'townLevelClaimed': townLevelClaimed,
        'musicEnabled': musicEnabled,
        'sfxEnabled': sfxEnabled,
        'vibrationEnabled': vibrationEnabled,
        'language': language.index,
        'difficulty': difficulty.index,
      };
}
