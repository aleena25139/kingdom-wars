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
    const options = GameBalance.battleSpeedOptions;
    final currentIndex = options.indexOf(speedMultiplier);
    speedMultiplier = options[(currentIndex + 1) % options.length];
  }

  /// Called every frame by the Flame game (or a headless test loop) with the
  /// real, unscaled delta time.
  void tick(double realDt) {
    final battle = activeBattle;
    if (battle == null || isPaused) return;
    // Ignore huge frame hitches (app switch, GC pause...) instead of
    // simulating them in one giant step.
    var remaining = realDt.clamp(0.0, _maxRealFrame).toDouble() * speedMultiplier;
    // At 2x / 3x one frame is a big chunk of game time. Run it as several
    // small steps so nothing "jumps over" its target, attack cooldowns and
    // projectiles stay accurate, and the army never looks frozen.
    while (remaining > 0) {
      final step = remaining < _maxSimStep ? remaining : _maxSimStep;
      lastResult = battle.tick(step);
      remaining -= step;
      if (battle.status != BattleStatus.ongoing) break;
    }
  }

  static const double _maxSimStep = 1 / 30; // biggest single simulation step
  static const double _maxRealFrame = 0.1; // longest real frame we simulate

  /// How much faster the ANIMATIONS must run so they match the game speed.
  /// Game logic runs at 2x/3x, so sprite animations (attack swings, walk
  /// cycles, effects) have to run at 2x/3x too -- otherwise an attack
  /// animation is still playing when the next hit arrives and soldiers look
  /// stuck in their attack pose.
  double get visualSpeed => (activeBattle == null || isPaused) ? 1.0 : speedMultiplier;

  void endBattle() {
    activeBattle = null;
    isPaused = false;
    speedMultiplier = GameBalance.battleSpeedOptions.first;
  }
}
