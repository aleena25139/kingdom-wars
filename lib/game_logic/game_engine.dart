// Sits above BattleEngine and is what Flame's game loop and the UI actually
// talk to. Handles starting a campaign level or endless run, pause/resume,
// and the 1x/2x/3x battle-speed toggle — none of which are per-battle
// combat rules, so they don't belong inside BattleEngine itself.
import '../constants/game_balance.dart';
import '../constants/level_data.dart';
import '../models/unit.dart';
import 'battle_engine.dart';

class GameEngine {
  BattleEngine? activeBattle;
  bool isPaused = false;
  double speedMultiplier = GameBalance.battleSpeedOptions.first;

  BattleResult? lastResult;

  bool get hasActiveBattle => activeBattle != null;

  void startCampaignLevel(
    int levelId, {
    required int playerCastleLevel,
    required Set<UnitType> unlockedUnitTypes,
    required Map<UnitType, int> unitLevels,
    required List<int> knightSlotLevels,
    Map<String, int> formation = const {},
  }) {
    final level = LevelData.byId(levelId);
    activeBattle = BattleEngine(
      playerCastleLevel: playerCastleLevel,
      unlockedUnitTypes: unlockedUnitTypes,
      unitLevels: unitLevels,
      knightSlotLevels: knightSlotLevels,
      formation: formation,
      level: level,
    );
    isPaused = false;
    lastResult = null;
  }

  void startEndless({
    required int playerCastleLevel,
    required Set<UnitType> unlockedUnitTypes,
    required Map<UnitType, int> unitLevels,
    required List<int> knightSlotLevels,
    Map<String, int> formation = const {},
  }) {
    activeBattle = BattleEngine(
      playerCastleLevel: playerCastleLevel,
      unlockedUnitTypes: unlockedUnitTypes,
      unitLevels: unitLevels,
      knightSlotLevels: knightSlotLevels,
      formation: formation,
      isEndless: true,
    );
    isPaused = false;
    lastResult = null;
  }

  void togglePause() => isPaused = !isPaused;
  void pause() => isPaused = true;
  void resume() => isPaused = false;

  void cycleSpeed() {
    final options = GameBalance.battleSpeedOptions;
    final currentIndex = options.indexOf(speedMultiplier);
    speedMultiplier = options[(currentIndex + 1) % options.length];
  }

  /// Called every frame by the Flame game (or a headless test loop) with the
  /// real, unscaled delta time.
  void tick(double realDt) {
    final battle = activeBattle;
    if (battle == null || isPaused) return;
    final scaledDt = realDt * speedMultiplier;
    lastResult = battle.tick(scaledDt);
  }

  void endBattle() {
    activeBattle = null;
    isPaused = false;
    speedMultiplier = GameBalance.battleSpeedOptions.first;
  }
}
