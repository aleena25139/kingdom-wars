// The single source of truth screens/widgets talk to via Provider. Wraps
// GameEngine (battle simulation) and PlayerProgress (persisted currency/
// progress), enforces spend checks (coins/diamonds) before mutating either,
// and calls notifyListeners() so the UI rebuilds. Actual disk persistence is
// delegated to SaveService (STEP 8) via the save()/load() calls here.
import 'package:flutter/foundation.dart';

import '../constants/game_balance.dart';
import '../constants/town_data.dart';
import '../constants/tower_data.dart';
import '../constants/unit_data.dart';
import '../models/player_progress.dart';
import '../models/tower.dart';
import '../models/treasure_chest.dart';
import '../models/unit.dart';
import '../services/cloud_sync.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import 'army_manager.dart';
import 'battle_engine.dart';
import 'game_engine.dart';

class StateProvider extends ChangeNotifier {
  PlayerProgress progress;
  final GameEngine gameEngine = GameEngine();

  StateProvider({PlayerProgress? initialProgress})
      : progress = initialProgress ?? PlayerProgress();

  /// Called once by LoadingScreen after SaveService finishes reading the
  /// real save file from disk — swaps the placeholder PlayerProgress() the
  /// provider started with for the actual saved data.
  void loadProgress(PlayerProgress loaded) {
    progress = loaded;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Treasure chests
  // ------------------------------------------------------------------

  bool get isFreeChestReady {
    final readyAt = progress.nextFreeChestReadyAt;
    return readyAt == null || !DateTime.now().isBefore(readyAt);
  }

  Duration get timeUntilFreeChest {
    final readyAt = progress.nextFreeChestReadyAt;
    if (readyAt == null) return Duration.zero;
    final remaining = readyAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Opens the free chest (caller should check isFreeChestReady first).
  /// Rolls a tier, grants coins/diamonds, and schedules the next one.
  ChestRewards openFreeChest() {
    final tier = _rollChestTier();
    final rewards = _rollRewardsFor(tier);
    progress.coins += rewards.coins;
    progress.diamonds += rewards.diamonds;
    progress.lastFreeChestOpenedAt = DateTime.now();
    progress.nextFreeChestReadyAt = DateTime.now().add(GameBalance.freeChestInterval);
    notifyListeners();
    return rewards;
  }

  ChestTier _rollChestTier() {
    final roll = DateTime.now().millisecondsSinceEpoch % 100;
    if (roll < 5) return ChestTier.legendary; // 5%
    if (roll < 30) return ChestTier.rare; // 25%
    return ChestTier.common; // 70%
  }

  ChestRewards _rollRewardsFor(ChestTier tier) {
    switch (tier) {
      case ChestTier.common:
        return const ChestRewards(coins: 150, diamonds: 5);
      case ChestTier.rare:
        return const ChestRewards(coins: 800, diamonds: 40);
      case ChestTier.legendary:
        return const ChestRewards(coins: 5000, diamonds: 500);
    }
  }

  // ------------------------------------------------------------------
  // Battle lifecycle
  // ------------------------------------------------------------------

  void startCampaignLevel(int levelId) {
    gameEngine.startCampaignLevel(
      levelId,
      playerCastleLevel: progress.castleLevel,
      unlockedUnitTypes: progress.unlockedUnitTypes,
      unitLevels: progress.unitLevels,
      knightSlotLevels: progress.knightSlotLevels,
      formation: progress.formation,
    );
    notifyListeners();
  }

  void startEndless() {
    gameEngine.startEndless(
      playerCastleLevel: progress.castleLevel,
      unlockedUnitTypes: progress.unlockedUnitTypes,
      unitLevels: progress.unitLevels,
      knightSlotLevels: progress.knightSlotLevels,
      formation: progress.formation,
    );
    notifyListeners();
  }

  /// Advances the active battle by [realDt] seconds. Called from a Flame
  /// update() or a Ticker — kept separate from notifyListeners() spam by
  /// only notifying when the battle actually ends this tick.
  void tickBattle(double realDt) {
    if (!gameEngine.hasActiveBattle) return;
    final wasOngoing = gameEngine.activeBattle!.status == BattleStatus.ongoing;
    gameEngine.tick(realDt);
    final isNowOver = gameEngine.activeBattle!.status != BattleStatus.ongoing;
    if (wasOngoing && isNowOver) {
      _applyBattleResult(gameEngine.lastResult!, levelId: gameEngine.activeBattle!.level?.id);
      notifyListeners();
    }
  }

  /// Result of the most recent Endless run (shown on the Defeat screen).
  int lastEndlessScore = 0;
  int lastEndlessWave = 0;
  int lastEndlessKills = 0;
  bool lastEndlessNewBest = false;

  void _applyBattleResult(BattleResult result, {int? levelId}) {
    progress.coins += result.coinsEarned;
    progress.diamonds += result.diamondsEarned;
    final endlessBattle = gameEngine.activeBattle;
    if (levelId == null && endlessBattle != null && endlessBattle.isEndless) {
      // Endless run finished (it can only end in defeat): remember the score.
      lastEndlessScore = endlessBattle.score;
      lastEndlessWave = endlessBattle.currentWaveNumber;
      lastEndlessKills = endlessBattle.enemiesKilled;
      lastEndlessNewBest = lastEndlessScore > progress.highestEndlessScore;
      if (lastEndlessNewBest) progress.highestEndlessScore = lastEndlessScore;
      if (lastEndlessWave > progress.highestEndlessWave) {
        progress.highestEndlessWave = lastEndlessWave;
      }
      // Publish a new best to the global leaderboard (silently skipped offline;
      // CloudSync sends it later once the phone is online again).
      if (lastEndlessNewBest) CloudSync.instance.submitBestNow();
    }
    if (result.status == BattleStatus.victory && levelId != null) {
      progress.unlockedLevelIds.add(levelId + 1);
      final existingStars = progress.starsPerLevel[levelId] ?? 0;
      if (result.starsEarned > existingStars) {
        progress.starsPerLevel[levelId] = result.starsEarned;
      }
    }
    if (result.status == BattleStatus.victory && levelId == null) {
      // Endless mode: track the best wave reached.
      final reached = gameEngine.activeBattle?.currentWaveNumber ?? 0;
      if (reached > progress.highestEndlessWave) {
        progress.highestEndlessWave = reached;
      }
    }
  }

  void togglePause() {
    gameEngine.togglePause();
    notifyListeners();
  }

  void pauseBattle() {
    gameEngine.pause();
    notifyListeners();
  }

  void resumeBattle() {
    gameEngine.resume();
    notifyListeners();
  }

  void cycleSpeed() {
    gameEngine.cycleSpeed();
    notifyListeners();
  }

  void exitBattle() {
    gameEngine.endBattle();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // In-battle player actions (spend coins, mutate the active BattleEngine)
  // ------------------------------------------------------------------

  bool buildTower(TowerType type, int col, int row) {
    final battle = gameEngine.activeBattle;
    if (battle == null) return false;
    final cost = TowerData.defFor(type).buildCost;
    if (progress.coins < cost) return false;
    final placed = battle.buildTower(type, col, row);
    if (placed == null) return false;
    progress.coins -= cost;
    notifyListeners();
    return true;
  }

  bool upgradeTower(String towerId, TowerType type, int currentLevel) {
    final battle = gameEngine.activeBattle;
    if (battle == null) return false;
    if (currentLevel >= 3) return false;
    final cost = TowerData.defFor(type).statAt(currentLevel + 1).upgradeCost;
    if (progress.coins < cost) return false;
    final upgraded = battle.upgradeTower(towerId);
    if (!upgraded) return false;
    progress.coins -= cost;
    notifyListeners();
    return true;
  }

  /// Tap on an idle unit button: starts filling that unit's own MP bar from
  /// the castle's MP pool.
  bool startCharge(UnitType type) {
    final battle = gameEngine.activeBattle;
    if (battle == null) return false;
    return battle.startCharge(type);
  }

  /// Full MP bar of a unit + tap = that type fights faster for 5s.
  bool activateBoost(UnitType type) {
    final battle = gameEngine.activeBattle;
    if (battle == null) return false;
    return battle.activateBoost(type);
  }

  bool deployReinforcement(UnitType type) {
    final battle = gameEngine.activeBattle;
    if (battle == null) return false;
    final isUnlocked =
        type == UnitType.knight ? progress.anyKnightUnlocked : progress.unlockedUnitTypes.contains(type);
    if (!isUnlocked) return false;
    final cost = UnitData.defFor(type).deployCost;
    if (progress.coins < cost) return false;
    final deployed = battle.deployReinforcement(type);
    if (!deployed) return false;
    progress.coins -= cost;
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------
  // Meta progression (main menu / castle upgrade screen)
  // ------------------------------------------------------------------

  /// Endless progression — there's no max level, cost just keeps climbing
  /// (see GameBalance.castleStatFor), so the only gate is affordability.
  bool upgradeCastle() {
    final nextLevel = progress.castleLevel + 1;
    final cost = GameBalance.castleStatFor(nextLevel).upgradeCost;
    if (progress.coins < cost) return false;
    progress.coins -= cost;
    progress.castleLevel = nextLevel;
    notifyListeners();
    return true;
  }

  /// Permanently unlocks an army unit type (one-time coins + diamonds spend
  /// from the Army screen). Once unlocked it starts at level 1 and both
  /// auto-spawns and becomes deployable in every future battle.
  ///
  /// Knight doesn't have a single "unlocked?" flag like Archer/Mage/Dragon —
  /// it's bought one squad slot at a time (see purchaseKnightSlot below).
  /// Previously this method just returned false for Knight outright, which
  /// meant any UI path that called purchaseUnit(UnitType.knight) instead of
  /// purchaseKnightSlot(slotIndex) would silently fail — always reporting
  /// "not enough coins" even with plenty of coins, since the real reason
  /// (wrong entry point) never surfaced. Routing Knight to the next
  /// available slot here instead makes this entry point work no matter
  /// which one a caller uses, rather than depending on every caller
  /// remembering Knight's special case.
  bool purchaseUnit(UnitType type) {
    if (type == UnitType.knight) {
      final nextSlot = progress.knightSlotLevels.indexOf(0);
      if (nextSlot == -1) return false; // every Knight slot already owned
      return purchaseKnightSlot(nextSlot);
    }
    if (progress.unlockedUnitTypes.contains(type)) return false;
    final def = UnitData.defFor(type);
    if (progress.coins < def.unlockCost || progress.diamonds < def.unlockDiamondCost) {
      return false;
    }
    progress.coins -= def.unlockCost;
    progress.diamonds -= def.unlockDiamondCost;
    progress.unlockedUnitTypes.add(type);
    progress.unitLevels[type] = 1;
    notifyListeners();
    return true;
  }

  /// Permanently upgrades an already-unlocked unit type to its next level
  /// (coins only), same pattern as upgradeCastle/upgradeTower. Caps at
  /// UnitDef.maxLevel (currently 3).
  ///
  /// Same reasoning as purchaseUnit above: Knight is upgraded per-slot via
  /// upgradeKnightSlot, but a caller that still goes through this generic
  /// entry point for Knight is routed to its lowest-level owned slot
  /// (the "next in line" one to upgrade) instead of silently failing.
  bool upgradeUnit(UnitType type) {
    if (type == UnitType.knight) {
      final ownedLevels = progress.knightSlotLevels.where((l) => l > 0);
      if (ownedLevels.isEmpty) return false; // no Knight owned yet
      final lowestLevel = ownedLevels.reduce((a, b) => a < b ? a : b);
      final slotIndex = progress.knightSlotLevels.indexOf(lowestLevel);
      return upgradeKnightSlot(slotIndex);
    }
    if (!progress.unlockedUnitTypes.contains(type)) return false;
    final def = UnitData.defFor(type);
    final currentLevel = progress.unitLevels[type] ?? 1;
    if (currentLevel >= def.maxLevel) return false;
    final cost = def.statAt(currentLevel + 1).upgradeCost;
    if (progress.coins < cost) return false;
    progress.coins -= cost;
    progress.unitLevels[type] = currentLevel + 1;
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------
  // Knight squad (5 individually-purchased, individually-upgraded slots)
  // ------------------------------------------------------------------

  /// Permanently unlocks Knight slot [slotIndex] (0-based). Slots must be
  /// bought in order — slot 1 requires slot 0 already unlocked, etc. — so
  /// the Army screen can show "Knight #1..#5" as a simple left-to-right
  /// progression instead of letting the player skip around.
  bool purchaseKnightSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= UnitData.knightMaxSlots) return false;
    if (progress.knightSlotLevels[slotIndex] > 0) return false; // already owned
    if (slotIndex > 0 && progress.knightSlotLevels[slotIndex - 1] == 0) return false;
    final cost = UnitData.knightSlotUnlockCosts[slotIndex];
    if (progress.coins < cost) return false;
    progress.coins -= cost;
    progress.knightSlotLevels[slotIndex] = 1;
    notifyListeners();
    return true;
  }

  /// Permanently upgrades one already-owned Knight slot to its next level
  /// (coins only, same cost table every unit type uses). Caps at
  /// UnitData.defFor(UnitType.knight).maxLevel (currently 3).
  bool upgradeKnightSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= UnitData.knightMaxSlots) return false;
    final currentLevel = progress.knightSlotLevels[slotIndex];
    if (currentLevel <= 0) return false; // not unlocked yet
    final def = UnitData.defFor(UnitType.knight);
    if (currentLevel >= def.maxLevel) return false;
    final cost = def.statAt(currentLevel + 1).upgradeCost;
    if (progress.coins < cost) return false;
    progress.coins -= cost;
    progress.knightSlotLevels[slotIndex] = currentLevel + 1;
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------
  // Formation: the player decides who stands where
  // ------------------------------------------------------------------

  /// The army exactly as it will stand on the battlefield right now.
  List<FormationSlot> currentFormationSlots() => ArmyManager.layout(
        unlockedUnitTypes: progress.unlockedUnitTypes,
        unitLevels: progress.unitLevels,
        knightSlotLevels: progress.knightSlotLevels,
        formation: progress.formation,
      );

  /// Moves soldier [key] to cell ([col],[row]). If another soldier already
  /// stands there the two swap places. Works between battles and during one
  /// (living soldiers then walk to their new cells).
  bool moveFormationUnit(String key, int col, int row) {
    if (col < 0 || col >= ArmyManager.gridCols || row < 0 || row >= ArmyManager.gridRows) return false;
    final slots = currentFormationSlots();
    final cells = <String, int>{for (final s in slots) s.key: ArmyManager.cellId(s.col, s.row)};
    final from = cells[key];
    if (from == null) return false;
    final to = ArmyManager.cellId(col, row);
    if (from == to) return false;
    String? other;
    for (final e in cells.entries) {
      if (e.value == to) other = e.key;
    }
    cells[key] = to;
    if (other != null) cells[other] = from;
    progress.formation = cells; // remember everyone's cell, not just the moved one
    gameEngine.activeBattle?.applyFormation(progress.formation);
    notifyListeners();
    return true;
  }

  /// Back to the default layout.
  void resetFormation() {
    progress.formation = {};
    gameEngine.activeBattle?.applyFormation(progress.formation);
    notifyListeners();
  }

  void updateSettings({
    bool? musicEnabled,
    bool? sfxEnabled,
    bool? vibrationEnabled,
    AppLanguage? language,
    Difficulty? difficulty,
  }) {
    if (musicEnabled != null) {
      progress.musicEnabled = musicEnabled;
      SoundService.instance.setMusicEnabled(musicEnabled);
    }
    if (sfxEnabled != null) {
      progress.sfxEnabled = sfxEnabled;
      SoundService.instance.setSfxEnabled(sfxEnabled);
    }
    if (vibrationEnabled != null) progress.vibrationEnabled = vibrationEnabled;
    if (language != null) progress.language = language;
    if (difficulty != null) progress.difficulty = difficulty;
    notifyListeners();
  }

  /// Wipes both the in-memory progress and the on-disk save (SaveService,
  /// STEP 8). Called from SettingsScreen's confirm-gated reset action.
  // ------------------------------------------------------------------
  // Town module (endless map, coins + diamonds, houses are free, no taxes)
  // ------------------------------------------------------------------

  int get townPopulation => TownData.populationOf(progress.townGrid);
  int get townHappiness => TownData.happinessOf(progress.townGrid);
  int get townScore => TownData.scoreOf(progress.townGrid);
  int get townLevel => TownData.levelForScore(townScore);

  bool isBuildingUnlocked(BuildingDef def) => progress.levelsWon >= def.unlockWins;

  /// Places [id] on tile (col,row). Returns null on success, otherwise a
  /// short reason to show the player.
  String? placeBuilding(String id, int col, int row) {
    final def = TownData.byId(id);
    if (def == null) return 'Unknown building';
    if (!TownData.inWorld(col, row)) return 'Outside the town';
    if (!isBuildingUnlocked(def)) return 'Win ${def.unlockWins} levels to unlock';
    final k = TownData.key(col, row);
    final existingId = progress.townGrid[k];
    BuildingDef? replaced;
    if (existingId != null) {
      // Bridges, boats and trains go ON TOP of a river / rail tile.
      if (def.placeOn.contains(existingId)) {
        replaced = TownData.byId(existingId);
      } else if (def.placeOn.isNotEmpty) {
        final names = def.placeOn.map((x) => TownData.byId(x)?.name ?? x).join(' or ');
        return '${def.name} must be placed on a $names tile';
      } else {
        return 'This spot is already used';
      }
    } else if (def.placeOn.isNotEmpty) {
      final names = def.placeOn.map((x) => TownData.byId(x)?.name ?? x).join(' or ');
      return '${def.name} must be placed on a $names tile';
    }
    if (progress.coins < def.coins) return 'Not enough coins (${def.coins} needed)';
    if (progress.diamonds < def.diamonds) return 'Not enough diamonds (${def.diamonds} needed)';
    progress.coins -= def.coins;
    progress.diamonds -= def.diamonds;
    progress.townGrid[k] = id;
    _afterTownChange();
    return null;
  }

  /// Demolishes whatever is on the tile and refunds part of its price.
  /// A bridge / boat / train leaves the river / rail underneath.
  String? demolish(int col, int row) {
    final k = TownData.key(col, row);
    final id = progress.townGrid[k];
    if (id == null) return 'Nothing to demolish here';
    final def = TownData.byId(id);
    if (def != null && def.placeOn.isNotEmpty) {
      progress.townGrid[k] = def.placeOn.first;
    } else {
      progress.townGrid.remove(k);
    }
    if (def != null) {
      progress.coins += TownData.refundCoins(def);
      progress.diamonds += TownData.refundDiamonds(def);
    }
    _afterTownChange();
    return null;
  }

  /// Town level-ups pay diamonds once per level. Returns diamonds granted.
  int _claimTownLevelRewards() {
    final lvl = townLevel;
    if (lvl <= progress.townLevelClaimed) return 0;
    var diamonds = 0;
    for (var l = progress.townLevelClaimed + 1; l <= lvl; l++) {
      diamonds += l * TownData.diamondsPerTownLevel;
    }
    progress.townLevelClaimed = lvl;
    progress.diamonds += diamonds;
    return diamonds;
  }

  /// Diamonds paid by the latest town level-up (UI shows it once, then clears).
  int pendingTownRewardDiamonds = 0;

  void _afterTownChange() {
    final d = _claimTownLevelRewards();
    if (d > 0) pendingTownRewardDiamonds = d;
    notifyListeners();
  }

  /// Name shown on the global leaderboard (2-16 characters).
  void setPlayerName(String name) {
    final n = name.trim();
    if (n.length < 2) return;
    progress.playerName = n.length > 16 ? n.substring(0, 16) : n;
    notifyListeners();
    CloudSync.instance.submitBestNow();
  }

  Future<void> resetProgress() async {
    progress = PlayerProgress();
    gameEngine.endBattle();
    await SaveService.instance.clear();
    await SaveService.instance.markChanged(); // so the reset wins over the old cloud copy
    notifyListeners();
  }
}
