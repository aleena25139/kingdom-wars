// The heart of a single battle. Owns every mutable battlefield entity
// (castles, units, enemies, towers, projectiles) and advances them all in
// tick(dt). Flame's KingdomWarsGame calls tick() every frame (scaled by the
// chosen battle speed) and its components just read this engine's lists to
// render — no game logic lives in Flame land.
import 'dart:math';

import '../constants/enemy_data.dart';
import '../constants/game_balance.dart';
import '../constants/tower_data.dart';
import '../constants/unit_data.dart';
import '../models/battle_fx.dart';
import '../models/castle.dart';
import '../models/enemy.dart';
import '../models/level.dart';
import '../models/projectile.dart';
import '../models/sound_cue.dart';
import '../models/tower.dart';
import '../models/unit.dart';
import 'army_manager.dart';
import 'combat_helper.dart';
import 'collision_helper.dart';
import 'path_manager.dart';
import 'targeting_helper.dart';
import 'wave_manager.dart';

enum BattleStatus { ongoing, victory, defeat }

class BattleResult {
  final BattleStatus status;
  final int coinsEarned;
  final int diamondsEarned;
  final int starsEarned; // 0-3, campaign only
  const BattleResult({
    required this.status,
    required this.coinsEarned,
    required this.diamondsEarned,
    required this.starsEarned,
  });
}

class BattleEngine {
  final LevelDef? level; // null when isEndless == true
  final bool isEndless;
  final ArmyManager armyManager;
  final WaveManager waveManager;

  late Castle playerCastle;
  final List<Unit> units = [];
  final List<Enemy> enemies = [];
  final List<Tower> towers = [];
  final List<Projectile> projectiles = [];
  final List<StormZone> stormZones = [];
  final List<BattleEffect> effects = [];
  final List<_SkyStrike> _skyStrikes = []; // Elf Prince fire falling from the sky
  final Random _rng = Random();

  /// Sounds requested this frame. The engine knows nothing about audio: the
  /// Flame game drains this list every frame and hands each cue to
  /// SoundService (which throttles, mixes and ducks the music).
  final List<SoundCue> soundQueue = [];
  void _cue(SoundCue c) {
    if (soundQueue.length < 60) soundQueue.add(c);
  }

  BattleStatus status = BattleStatus.ongoing;
  int coinsEarnedThisBattle = 0;

  /// Endless-mode score: every kill gives points (tougher enemies = more),
  /// and every new wave reached adds a bonus. Shown live in the HUD and
  /// saved as the best score when the run ends.
  int score = 0;
  int enemiesKilled = 0;

  // ---- MP (mana) + per-unit MP + unit-type boost -----------------------
  // CASTLE MP ("the whole pool"): starts FULL. It refills slowly by itself,
  // and the unit bars below draw from it while they charge. If it ever hits
  // ZERO the battle is lost, exactly like losing the castle.
  late final double maxMp;
  late double mp;

  /// Every unit type has its OWN small MP bar (Archer = 50 MP, ...). Charging
  /// it takes that many points out of the castle pool, a bit at a time, so a
  /// bar needs some time to fill. A full bar can be spent on a boost.
  final Map<UnitType, double> _unitMp = {};
  final Set<UnitType> _charging = {};

  /// Seconds of boost left, per unit type (only types currently boosted).
  final Map<UnitType, double> _boostLeft = {};

  /// Why the battle ended in defeat (the Defeat screen shows a matching text).
  bool defeatedByMp = false;

  bool get mpLow => mp <= maxMp * 0.2;
  bool isBoosted(UnitType type) => (_boostLeft[type] ?? 0) > 0;
  double boostLeftFor(UnitType type) => _boostLeft[type] ?? 0;

  double unitMpMax(UnitType type) => UnitData.mpCostOf(type).toDouble();
  double unitMpOf(UnitType type) => _unitMp[type] ?? 0;
  bool unitMpFull(UnitType type) => unitMpOf(type) >= unitMpMax(type) - 0.001;
  bool isCharging(UnitType type) => _charging.contains(type);

  /// Tap on an idle unit button: start filling that unit's own MP bar from the
  /// castle pool. Nothing is spent if the bar is already full / charging.
  bool startCharge(UnitType type) {
    if (status != BattleStatus.ongoing) return false;
    if (unitMpFull(type) || isCharging(type) || isBoosted(type)) return false;
    if (aliveOf(type) == 0) return false;
    if (mp <= 0) return false;
    _charging.add(type);
    return true;
  }

  /// Tap on a unit type whose own MP bar is full: every living soldier of that
  /// type attacks twice as fast for a few seconds. Empties that unit's bar.
  bool activateBoost(UnitType type) {
    if (status != BattleStatus.ongoing || !unitMpFull(type)) return false;
    if (aliveOf(type) == 0) return false;
    _unitMp[type] = 0;
    _charging.remove(type);
    _boostLeft[type] = GameBalance.boostSeconds;
    _cue(SoundCue.deployHorn);
    return true;
  }

  void _tickMp(double dt) {
    // 1) castle pool refills slowly
    mp = min(maxMp, mp + (maxMp / GameBalance.mpRegenSeconds) * dt);

    // 2) charging unit bars pull their MP out of the castle pool
    if (_charging.isNotEmpty) {
      for (final t in _charging.toList()) {
        final cost = unitMpMax(t);
        final have = unitMpOf(t);
        final rate = cost / UnitData.mpChargeSecondsOf(t); // MP per second
        final want = min(rate * dt, cost - have);
        final take = min(want, max(0.0, mp));
        mp -= take;
        _unitMp[t] = have + take;
        if (unitMpFull(t)) _charging.remove(t);
      }
    }

    // 3) boost timers
    if (_boostLeft.isNotEmpty) {
      for (final t in _boostLeft.keys.toList()) {
        final left = _boostLeft[t]! - dt;
        if (left <= 0) {
          _boostLeft.remove(t);
        } else {
          _boostLeft[t] = left;
        }
      }
    }

    // 4) castle MP finished -> game over
    if (mp <= 0.001) {
      mp = 0;
      defeatedByMp = true;
      status = BattleStatus.defeat;
    }
  }

  int _towerIdCounter = 0;
  int _projectileIdCounter = 0;
  double _endlessStatMultiplier = 1.0;
  int _endlessWaveCounter = 0;
  double _timeSinceEndlessWaveStart = 0;
  static const double _endlessWaveDuration = 25.0; // seconds per endless "wave"

  BattleEngine({
    required int playerCastleLevel,
    required Set<UnitType> unlockedUnitTypes,
    required Map<UnitType, int> unitLevels,
    required List<int> knightSlotLevels,
    Map<String, int> formation = const {},
    this.level,
    this.isEndless = false,
  })  : waveManager = level != null ? WaveManager.forLevel(level) : WaveManager([]),
        armyManager = ArmyManager(
          unlockedUnitTypes: unlockedUnitTypes,
          unitLevels: unitLevels,
          knightSlotLevels: knightSlotLevels,
          formation: formation,
        ) {
    final (px, py) = (PathManager.playerCastleX, PathManager.laneCenterY);
    playerCastle = Castle.playerAtLevel(playerCastleLevel, x: px, y: py);
    maxMp = GameBalance.maxMpFor(playerCastleLevel).toDouble();
    mp = maxMp; // MP starts completely full
    // The army is permanent: everyone stands in formation from the first
    // frame, and nobody spawns on a timer afterwards.
    units.addAll(armyManager.initialUnits(playerCastle));
  }

  int get currentWaveNumber => isEndless ? _endlessWaveCounter + 1 : waveManager.currentWaveNumber;
  int get totalWaves => isEndless ? -1 : waveManager.totalWaves; // -1 = "infinite" for UI

  // ------------------------------------------------------------------
  // Player actions (called from UI via StateProvider)
  // ------------------------------------------------------------------

  Tower? buildTower(TowerType type, int col, int row) {
    final alreadyThere = towers.any((t) => t.gridCol == col && t.gridRow == row);
    if (alreadyThere) return null;
    final (x, y) = PathManager.towerSlotPosition(col, row);
    final tower = Tower(
      id: 'tower_${_towerIdCounter++}',
      type: type,
      gridCol: col,
      gridRow: row,
      x: x,
      y: y,
    );
    towers.add(tower);
    return tower;
  }

  bool upgradeTower(String towerId) {
    final tower = towers.where((t) => t.id == towerId).firstOrNull;
    if (tower == null || tower.isMaxLevel) return false;
    tower.upgrade();
    return true;
  }

  /// Pays-to-replace a fallen soldier: puts a new one into an empty
  /// formation slot of that type. False (and no cost, see StateProvider) if
  /// that type is already at full strength.
  bool deployReinforcement(UnitType unitType) {
    final unit = armyManager.deployReinforcement(unitType, units);
    if (unit == null) return false;
    units.add(unit);
    _cue(SoundCue.deployHorn);
    return true;
  }

  /// The player rearranged the army (Formation screen) while a battle is on:
  /// every living soldier walks to its new cell.
  void applyFormation(Map<String, int> formation) {
    armyManager.setFormation(formation);
    for (final unit in units) {
      if (!unit.alive) continue;
      FormationSlot? slot;
      for (final s in armyManager.slots) {
        if (s.key == unit.formationKey) {
          slot = s;
          break;
        }
      }
      if (slot == null) continue;
      unit.slot = slot.index;
      unit.homeY = slot.y;
      // Air-strikers (Phoenix) fly out to their own station; only their
      // lane (y) is rearranged.
      if (!unit.isAirStriker) unit.homeX = slot.x;
    }
  }

  bool canDeploy(UnitType type) => armyManager.canDeploy(type, units);
  int aliveOf(UnitType type) => armyManager.aliveOf(type, units);
  int squadSizeOf(UnitType type) => armyManager.squadSizeOf(type);

  // ------------------------------------------------------------------
  // Main tick
  // ------------------------------------------------------------------

  BattleResult tick(double dt) {
    if (status != BattleStatus.ongoing) {
      return _resultFor(status);
    }

    _tickMp(dt);
    if (status != BattleStatus.ongoing) return _resultFor(status); // castle MP ran out
    _spawnFromCastlesAndWaves(dt);
    _updateMovementAndMeleeCombat(dt);
    _fireTowerProjectiles(dt);
    _advanceProjectiles(dt);
    _tickStormZones(dt);
    _tickSkyStrikes(dt);
    _tickEffects(dt);
    _tickStatusEffects(dt);
    _cleanupDead();
    _checkWaveProgress();
    _checkWinLose();

    return _resultFor(status);
  }

  void _spawnFromCastlesAndWaves(double dt) {
    if (isEndless) {
      _timeSinceEndlessWaveStart += dt;
      if (_timeSinceEndlessWaveStart >= _endlessWaveDuration) {
        _timeSinceEndlessWaveStart = 0;
        _endlessWaveCounter++;
        _endlessStatMultiplier += GameBalance.enemyStatScalePerWave;
        score += GameBalance.endlessWaveBonusScore * (_endlessWaveCounter + 1);
      }
      // Endless mode spawns a steady trickle scaled by _endlessStatMultiplier;
      // reuse WaveManager's spawn logic isn't needed since there's no fixed
      // wave list, so we spawn directly here at a fixed cadence.
      _endlessSpawnTimer -= dt;
      if (_endlessSpawnTimer <= 0) {
        _endlessSpawnTimer = max(0.4, 1.5 - _endlessWaveCounter * 0.02);
        final endlessEnemy = _spawnEndlessEnemy();
        enemies.add(endlessEnemy);
        _announceSpawns([endlessEnemy]);
      }
    } else {
      final spawned = waveManager.tick(dt);
      enemies.addAll(spawned);
      _announceSpawns(spawned);
    }
  }

  /// Big / noisy enemies announce themselves the moment they appear.
  void _announceSpawns(List<Enemy> spawned) {
    for (final e in spawned) {
      switch (e.type) {
        case EnemyType.lizard:
          _cue(SoundCue.lizardRoar);
          break;
        case EnemyType.monster:
          _cue(SoundCue.monsterGrowl);
          break;
        case EnemyType.thunderTitan:
          _cue(SoundCue.titanRoar);
          break;
        case EnemyType.goblin:
          _cue(SoundCue.goblinCackle);
          break;
        case EnemyType.emberHound:
          _cue(SoundCue.houndBark);
          break;
        case EnemyType.blackDragon:
          _cue(SoundCue.dragonRoar);
          break;
        case EnemyType.skeleton:
        case EnemyType.skeletonArcher:
        case EnemyType.stormKnight:
        case EnemyType.stormCaller:
          break;
      }
    }
  }

  SoundCue _unitAttackCue(Unit u) {
    switch (u.type) {
      case UnitType.archer:
        return SoundCue.arrowShot;
      case UnitType.knight:
        return SoundCue.swordClash;
      case UnitType.mage:
        return SoundCue.mageZap;
      case UnitType.dragon:
        return SoundCue.dragonRoar;
      case UnitType.pandaWarrior:
        return SoundCue.pandaHit;
      case UnitType.elfPrince:
        return SoundCue.fireWhoosh;
      case UnitType.magician:
        return SoundCue.mageZap;
      case UnitType.phoenix:
        return SoundCue.phoenixCry;
    }
  }

  SoundCue _enemyAttackCue(Enemy e) {
    switch (e.type) {
      case EnemyType.skeleton:
        return SoundCue.skeletonRattle;
      case EnemyType.skeletonArcher:
        return SoundCue.arrowShot;
      case EnemyType.goblin:
        return SoundCue.goblinHit;
      case EnemyType.lizard:
        return SoundCue.lizardBite;
      case EnemyType.monster:
        return SoundCue.monsterGrowl;
      case EnemyType.stormKnight:
        return SoundCue.swordClash;
      case EnemyType.emberHound:
        return SoundCue.houndBark;
      case EnemyType.stormCaller:
        return SoundCue.thunder;
      case EnemyType.thunderTitan:
        return SoundCue.titanRoar;
      case EnemyType.blackDragon:
        return SoundCue.fireWhoosh;
    }
  }

  double _endlessSpawnTimer = 1.5;

  // Panda Warrior strikes anything within this distance of his slot (a bit
  // longer than the Lizard/Monster's own reach, so nothing out-ranges him).
  static const double _kungFuReach = 1.5;

  int _dragonWaveMarker = -1;
  int _dragonsThisWave = 0;

  bool _blackDragonDue() {
    if (_dragonWaveMarker != _endlessWaveCounter) {
      _dragonWaveMarker = _endlessWaveCounter;
      _dragonsThisWave = 0;
    }
    final quota = (_endlessWaveCounter % 5 == 4) ? 2 : 1;
    return _dragonsThisWave < quota && _timeSinceEndlessWaveStart >= 6.0 * (_dragonsThisWave + 1);
  }

  Enemy _spawnEndlessEnemy() {
    final (x, y) = PathManager.enemySpawnPoint(enemies.length);
    // Once things ramp up a bit, mix in skeleton archers, Lizards and
    // Monsters alongside the basic melee skeletons for variety, same 5-slot
    // pattern campaign waves use (see LevelData._enemyTypeForSpawn).
    EnemyType type;
    if (_endlessWaveCounter < 1) {
      type = EnemyType.skeleton;
    } else if (_blackDragonDue()) {
      // Bad dragon: from the 2nd endless wave on, one black dragon flies in
      // each wave (two on every 5th wave), a few seconds after the wave starts.
      type = EnemyType.blackDragon;
      _dragonsThisWave++;
    } else {
      switch (enemies.length % 5) {
        case 2:
          type = EnemyType.skeletonArcher;
          break;
        case 3:
          type = EnemyType.lizard;
          break;
        case 4:
          type = EnemyType.monster; // TEST: from the first endless wave (orig: wave >= 3)
          break;
        case 0:
          type = EnemyType.goblin; // goblin packs in endless too
          break;
        default:
          type = EnemyType.skeleton;
      }
    }
    final def = EnemyData.defFor(type);
    return Enemy(
      id: 'endless_enemy_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      spriteName: def.spriteName,
      maxHp: (def.hp * _endlessStatMultiplier).round(),
      damage: (def.damage * _endlessStatMultiplier).round(),
      baseSpeed: def.speed,
      isFlying: def.isFlying,
      isRanged: def.isRanged,
      range: def.range,
      attackKind: def.attackKind,
      meleeReach: def.meleeReach,
      attackInterval: def.attackInterval,
      aggroRange: def.aggroRange,
      cleaveRadius: def.cleaveRadius,
      cleaveFraction: def.cleaveFraction,
      x: x,
      y: y,
    );
  }

  void _updateMovementAndMeleeCombat(double dt) {
    // Formation soldiers NEVER move: they hold their slot and only fight
    // what comes into range (ranged units shoot, Knights call lightning,
    // Panda Warriors kung-fu anything that walks up to them).
    for (final unit in units) {
      if (!unit.alive) continue;
      // Boosted type: the attack cooldown (and a dragon's turn) run faster.
      final speedFx = isBoosted(unit.type) ? GameBalance.boostAttackSpeed : 1.0;
      unit.attackCooldown = max(0, unit.attackCooldown - dt * speedFx);
      if (unit.turnWait > 0) unit.turnWait = max(0, unit.turnWait - dt * speedFx);
      if (unit.healsNearby) _tickHealer(unit, dt);
      if (unit.usesMindControl) _tickMindControl(unit, dt * speedFx);

      // Player rearranged the formation: glide to the new cell.
      final hx = unit.homeX;
      if (hx != null) {
        unit.x = _approach(unit.x, hx, 4.0 * dt);
        if ((unit.x - hx).abs() < 0.001) unit.homeX = null;
      }
      final hy = unit.homeY;
      if (hy != null) {
        unit.y = _approach(unit.y, hy, 4.0 * dt);
        if ((unit.y - hy).abs() < 0.001) unit.homeY = null;
      }

      // Phoenix: fly out over the enemy zone first, then fire from there
      // (it keeps shooting on the way if something is already in range).
      if (unit.isAirStriker && unit.x < unit.advanceToX - 0.02) {
        unit.x = min(unit.advanceToX, unit.x + unit.advanceSpeed * dt);
      }

      final engageRange = (unit.isRanged || unit.usesLightning)
          ? unit.range
          : (unit.usesKungFu ? _kungFuReach : CollisionHelper.meleeEngageDistance);
      final target = TargetingHelper.nearestEnemyTo(
        unit.x,
        unit.y,
        enemies,
        maxRange: engageRange,
        flyingOnly: false,
      );

      if (target == null) {
        unit.targetEnemyId = null;
        continue;
      }
      unit.targetEnemyId = target.id;

      // Dragon / Phoenix: if the enemy is BEHIND us, turn around to face it
      // first (the sprite flips with a quick turn animation), and only fire
      // once the turn has finished.
      if (unit.type == UnitType.phoenix || unit.type == UnitType.dragon) {
        final dx = target.x - unit.x;
        if (dx.abs() > 0.05) {
          final wantLeft = dx < 0;
          if (wantLeft != unit.facingLeft) {
            unit.facingLeft = wantLeft;
            unit.turnWait = 0.4;
          }
        }
        if (unit.turnWait > 0) continue;
      }
      if (unit.attackCooldown > 0) continue;

      if (unit.type == UnitType.mage) {
        // Mage: instant BLUE lightning.
        _mageBlueLightning(unit, target);
      } else if (unit.type == UnitType.phoenix || unit.type == UnitType.dragon) {
        // Dragon / Phoenix: breathe a jet of fire from the mouth.
        _dragonFireBreath(unit, target);
      } else if (unit.type == UnitType.elfPrince) {
        // Elf Prince: fire falls from the SKY.
        _elfPrinceSkyFire(unit, target);
      } else if (unit.isRanged) {
        // Ranged units loose a visible projectile that flies to the target and
        // only deals damage on arrival (see _advanceProjectiles): arrows,
        // Phoenix fireballs, Magician magic balls.
        _fireUnitArrow(unit, target);
      } else {
        target.takeDamage(unit.damage);
        if (unit.usesKungFu) {
          // Every 3rd hit is a spin kick that sweeps nearby enemies.
          unit.comboCount++;
          if (unit.comboCount % 3 == 0) {
            for (final swept in TargetingHelper.enemiesWithinRadius(target.x, target.y, 1.3, enemies)) {
              if (swept.id != target.id) swept.takeDamage((unit.damage * 0.6).round());
            }
          }
        }
        if (unit.isAoe) {
          for (final splashed in TargetingHelper.enemiesWithinRadius(target.x, target.y, 1.0, enemies)) {
            if (splashed.id != target.id) splashed.takeDamage((unit.damage * 0.4).round());
          }
        }
      }
      // Sounds for this attack (SoundService throttles + keeps them quiet).
      _cue(_unitAttackCue(unit));
      if (unit.type == UnitType.dragon || unit.type == UnitType.phoenix) _cue(SoundCue.fireWhoosh);
      if (unit.usesKungFu && unit.comboCount % 3 == 0) _cue(SoundCue.pandaRoar);
      // Kung-fu fighters strike faster (a flurry) than other units.
      unit.attackCooldown = unit.usesKungFu ? 0.75 : 1.0;
    }

    _updateEnemies(dt);
  }

  // ------------------------------------------------------------------
  // Enemy AI. Enemies act on their own (they no longer wait to be hit):
  //   1. If one of your units is within sight (aggroRange) they walk up to
  //      it -- including units standing right next to your castle -- and
  //      once within reach they bite / claw / shoot it every attackInterval.
  //   2. Otherwise they keep marching on the castle. On arrival they stop
  //      at the wall and keep attacking it until they're killed (they no
  //      longer vanish after a single hit).
  // ------------------------------------------------------------------
  void _updateEnemies(double dt) {
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      enemy.attackCooldown = max(0, enemy.attackCooldown - dt);
      enemy.targetUnitId = null;
      enemy.attackingCastle = false;

      // Mind-controlled Goblins / Orcs fight for the player.
      if (enemy.charmed) {
        _updateCharmedAlly(enemy, dt);
        continue;
      }

      final reach = enemy.isRanged ? enemy.range : enemy.meleeReach;

      // Plain melee / arrow enemies also lash out at any charmed traitor
      // standing in reach (special-attack enemies keep their normal AI).
      if (enemy.attackKind == EnemyAttackKind.melee || enemy.attackKind == EnemyAttackKind.arrow) {
        Enemy? traitor;
        var traitorDist = double.infinity;
        for (final c in enemies) {
          if (!c.alive || !c.charmed) continue;
          final d = CollisionHelper.distance(enemy.x, enemy.y, c.x, c.y);
          if (d <= reach && d < traitorDist) {
            traitor = c;
            traitorDist = d;
          }
        }
        if (traitor != null) {
          enemy.facingLeft = traitor.x < enemy.x;
          if (enemy.attackCooldown <= 0) {
            enemy.strikeCount++;
            enemy.aimX = traitor.x;
            enemy.aimY = traitor.y;
            _cue(_enemyAttackCue(enemy));
            traitor.takeDamage(enemy.damage);
            enemy.attackCooldown = enemy.attackInterval;
          }
          continue;
        }
      }
      final sight = max(enemy.aggroRange, reach);
      final targetUnit = TargetingHelper.nearestUnitTo(
        enemy.x,
        enemy.y,
        units,
        maxRange: sight,
        skipAirStrikers: !enemy.isRanged,
      );

      if (targetUnit != null) {
        enemy.targetUnitId = targetUnit.id;
        final d = CollisionHelper.distance(enemy.x, enemy.y, targetUnit.x, targetUnit.y);
        if (d <= reach) {
          enemy.facingLeft = targetUnit.x < enemy.x;
          if (enemy.attackCooldown <= 0) {
            _enemyStrikeUnit(enemy, targetUnit);
            enemy.attackCooldown = enemy.attackInterval;
          }
        } else {
          _moveEnemyToward(enemy, targetUnit.x, targetUnit.y, dt);
        }
        continue;
      }

      // Bow-armed enemies plant their feet once the castle is in range and
      // shoot it from there.
      if (enemy.isRanged && enemy.x <= enemy.range) {
        enemy.attackingCastle = true;
        enemy.facingLeft = true;
        if (enemy.attackCooldown <= 0) {
          enemy.strikeCount++;
          enemy.aimX = playerCastle.x;
          enemy.aimY = playerCastle.y;
          _enemyStrikeCastle(enemy);
          enemy.attackCooldown = enemy.attackInterval;
        }
        continue;
      }

      // Melee enemies that reach the wall stop and keep hitting it.
      if (!enemy.isRanged && enemy.x <= PathManager.castleContactX + enemy.meleeReach * 0.25) {
        enemy.attackingCastle = true;
        enemy.facingLeft = true;
        if (enemy.attackCooldown <= 0) {
          enemy.strikeCount++;
          enemy.aimX = playerCastle.x + 0.6;
          enemy.aimY = enemy.y;
          _cue(_enemyAttackCue(enemy));
          playerCastle.takeDamage(enemy.damage);
          if (enemy.attackKind == EnemyAttackKind.swordSlash) {
            // Storm Knight: the sword hits the CASTLE directly, and the same
            // sweep cuts every soldier standing around the wall.
            effects.add(BattleEffect(
              kind: BattleEffectKind.swordSlash,
              x: enemy.x,
              y: enemy.y,
              x2: playerCastle.x + 0.9,
              y2: enemy.y,
              life: 0.4,
              seed: _rng.nextInt(1 << 20),
            ));
            final swept = (enemy.damage * enemy.cleaveFraction).round();
            for (final u in TargetingHelper.unitsWithinRadius(enemy.x, enemy.y, enemy.cleaveRadius + 0.6, units)) {
              if (!u.isAirStriker) u.takeDamage(swept);
            }
          }
          enemy.attackCooldown = enemy.attackInterval;
        }
        continue;
      }

      // Nothing to fight yet -- keep marching toward the castle.
      enemy.facingLeft = true;
      enemy.x += enemy.effectiveSpeed * PathManager.enemyDirection * dt;
    }
  }

  // ------------------------------------------------------------------
  // Elf Prince: MIND CONTROL
  // Every few seconds the Prince enchants Goblins and Orcs (the Monster
  // brute) in his range. They switch sides: green glow, they walk up to the
  // nearest enemy and fight it, and the rest of the enemy army hits back at
  // them. The spell wears off after a while (the traitor fades away; no coin
  // or score is awarded for it) and nothing is ever charmed beyond the cap.
  // ------------------------------------------------------------------
  static const int _maxCharmed = 6;
  static const double _charmCooldown = 9.0;

  static bool _canBeCharmed(Enemy e) => e.type == EnemyType.goblin || e.type == EnemyType.monster;

  int _charmCountFor(int level) => 1 + (level >= 3 ? 1 : 0) + (level >= 5 ? 1 : 0);
  double _charmSecondsFor(int level) => 14.0 + 2.0 * level;

  int get charmedCount => enemies.where((e) => e.alive && e.charmed).length;

  void _tickMindControl(Unit prince, double dt) {
    prince.charmTimer -= dt;
    if (prince.charmTimer > 0) return;
    final room = _maxCharmed - charmedCount;
    final candidates = enemies
        .where((e) =>
            e.alive &&
            !e.charmed &&
            _canBeCharmed(e) &&
            CollisionHelper.distance(prince.x, prince.y, e.x, e.y) <= prince.range)
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x)); // the ones closest to our castle first
    if (room <= 0 || candidates.isEmpty) {
      prince.charmTimer = 0.75; // nothing to enchant yet, look again soon
      return;
    }
    final n = min(room, min(candidates.length, _charmCountFor(prince.level)));
    for (var i = 0; i < n; i++) {
      final e = candidates[i];
      e.charmed = true;
      e.charmTimeLeft = _charmSecondsFor(prince.level);
      e.hp = max(e.hp, (e.maxHp * 0.6).round());
      e.slowFactor = 0;
      e.slowDurationRemaining = 0;
      e.burnDamagePerTick = 0;
      e.burnDurationRemaining = 0;
      e.targetUnitId = null;
      e.attackingCastle = false;
      effects.add(BattleEffect(
        kind: BattleEffectKind.magicBurst,
        x: e.x,
        y: e.y,
        life: 0.9,
        seed: _rng.nextInt(1 << 20),
      ));
    }
    effects.add(BattleEffect(kind: BattleEffectKind.heal, x: prince.x, y: prince.y, radius: 1.6, life: 0.8));
    _cue(SoundCue.mageZap);
    _cue(SoundCue.healChime);
    prince.charmTimer = _charmCooldown;
  }

  void _updateCharmedAlly(Enemy ally, double dt) {
    ally.charmTimeLeft -= dt;
    if (ally.charmTimeLeft <= 0) {
      // The spell ends: the traitor vanishes in a puff of light.
      effects.add(BattleEffect(
        kind: BattleEffectKind.magicBurst,
        x: ally.x,
        y: ally.y,
        life: 0.7,
        seed: _rng.nextInt(1 << 20),
      ));
      ally.hp = 0;
      ally.alive = false;
      return;
    }

    // Nearest hostile enemy on the ground (melee traitors can't reach flyers).
    Enemy? foe;
    var foeDist = double.infinity;
    for (final e in enemies) {
      if (!e.alive || e.charmed || e.isFlying) continue;
      final d = CollisionHelper.distance(ally.x, ally.y, e.x, e.y);
      if (d < foeDist) {
        foe = e;
        foeDist = d;
      }
    }

    if (foe == null) {
      // Nobody to fight: stand guard in front of the castle, facing the lane.
      const guardX = PathManager.castleContactX + 2.5;
      if (ally.x > guardX + 0.1) {
        _moveEnemyToward(ally, guardX, ally.y, dt);
      } else {
        ally.facingLeft = false;
      }
      return;
    }

    final reach = ally.isRanged ? ally.range : ally.meleeReach;
    if (foeDist <= reach) {
      ally.facingLeft = foe.x < ally.x;
      if (ally.attackCooldown <= 0) {
        ally.strikeCount++;
        ally.aimX = foe.x;
        ally.aimY = foe.y;
        _cue(_enemyAttackCue(ally));
        foe.takeDamage(ally.damage);
        if (ally.cleaveRadius > 0) {
          final swept = (ally.damage * ally.cleaveFraction).round();
          for (final other in TargetingHelper.enemiesWithinRadius(foe.x, foe.y, ally.cleaveRadius, enemies)) {
            if (other.id != foe.id) other.takeDamage(swept);
          }
        }
        ally.attackCooldown = ally.attackInterval;
      }
    } else {
      _moveEnemyToward(ally, foe.x, foe.y, dt);
    }
  }

  static double _approach(double cur, double target, double step) {
    if ((target - cur).abs() <= step) return target;
    return cur + (target > cur ? step : -step);
  }

  void _moveEnemyToward(Enemy enemy, double tx, double ty, double dt) {
    final dx = tx - enemy.x;
    final dy = ty - enemy.y;
    final dist = max(0.0001, sqrt(dx * dx + dy * dy));
    final step = min(dist, enemy.effectiveSpeed * dt);
    enemy.x += dx / dist * step;
    enemy.y += dy / dist * step;
    enemy.x = max(enemy.x, PathManager.playerCastleX + 0.5);
    if (dx.abs() > 0.05) enemy.facingLeft = dx < 0;
  }

  /// One enemy attack on one of your units: a melee bite/claw lands
  /// immediately; a bow-armed enemy looses an arrow instead.
  void _enemyStrikeUnit(Enemy enemy, Unit target) {
    _cue(_enemyAttackCue(enemy));
    enemy.strikeCount++;
    enemy.aimX = target.x;
    enemy.aimY = target.y;
    switch (enemy.attackKind) {
      case EnemyAttackKind.lightning:
        _enemyLightning(enemy, target);
        return;
      case EnemyAttackKind.fireBreath:
        _enemyFireBreath(enemy, target);
        return;
      case EnemyAttackKind.stormSummon:
        _enemySummonStorm(enemy, target.x, target.y);
        return;
      case EnemyAttackKind.fireStones:
        _enemyThrowFireStone(enemy, ProjectileTargetKind.unit, target);
        return;
      case EnemyAttackKind.swordSlash:
        _enemySwordSlash(enemy, target);
        return;
      case EnemyAttackKind.melee:
      case EnemyAttackKind.arrow:
        break;
    }
    if (enemy.isRanged) {
      _fireEnemyArrowAtUnit(enemy, target);
    } else {
      target.takeDamage(enemy.damage);
      // Claw sweep: rake everyone standing next to the victim too.
      if (enemy.cleaveRadius > 0) {
        final swept = (enemy.damage * enemy.cleaveFraction).round();
        for (final other in TargetingHelper.unitsWithinRadius(target.x, target.y, enemy.cleaveRadius, units)) {
          if (other.id != target.id) other.takeDamage(swept);
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // Thunderstorm chapter special attacks
  // ------------------------------------------------------------------

  /// Attack on the castle itself, dispatched by attack kind. (Units are hit
  /// via [_enemyStrikeUnit].)
  void _enemyStrikeCastle(Enemy enemy) {
    _cue(_enemyAttackCue(enemy));
    switch (enemy.attackKind) {
      case EnemyAttackKind.lightning:
        playerCastle.takeDamage(enemy.damage);
        effects.add(BattleEffect(
          kind: BattleEffectKind.bolt,
          x: enemy.x,
          y: enemy.y,
          x2: playerCastle.x + 0.5,
          y2: playerCastle.y,
          seed: _rng.nextInt(1 << 20),
        ));
        break;
      case EnemyAttackKind.fireBreath:
        playerCastle.takeDamage(enemy.damage);
        effects.add(BattleEffect(
          kind: BattleEffectKind.bark,
          x: enemy.x,
          y: enemy.y,
          life: 0.6,
        ));
        effects.add(BattleEffect(
          kind: BattleEffectKind.fireJet,
          x: enemy.x,
          y: enemy.y,
          x2: playerCastle.x + 0.5,
          y2: playerCastle.y,
          life: 0.45,
          seed: _rng.nextInt(1 << 20),
        ));
        break;
      case EnemyAttackKind.stormSummon:
        _enemySummonStorm(enemy, playerCastle.x + 0.4, playerCastle.y);
        break;
      case EnemyAttackKind.fireStones:
        _enemyThrowFireStone(enemy, ProjectileTargetKind.castle, null);
        break;
      case EnemyAttackKind.swordSlash:
        playerCastle.takeDamage(enemy.damage);
        break;
      case EnemyAttackKind.melee:
      case EnemyAttackKind.arrow:
        _fireEnemyArrowAtCastle(enemy);
        break;
    }
  }

  /// Storm Knight: swings his sword at a soldier; the slash also cuts every
  /// other soldier around it (sweep) for [cleaveFraction] of the damage.
  void _enemySwordSlash(Enemy enemy, Unit target) {
    target.takeDamage(enemy.damage);
    final swept = (enemy.damage * enemy.cleaveFraction).round();
    for (final other in TargetingHelper.unitsWithinRadius(target.x, target.y, enemy.cleaveRadius, units)) {
      if (other.id != target.id && !other.isAirStriker) other.takeDamage(swept);
    }
    effects.add(BattleEffect(
      kind: BattleEffectKind.swordSlash,
      x: enemy.x,
      y: enemy.y,
      x2: target.x,
      y2: target.y,
      life: 0.4,
      seed: _rng.nextInt(1 << 20),
    ));
  }

  // ------------------------------------------------------------------
  // Hero special attacks
  // ------------------------------------------------------------------

  /// Mage: an instant bolt of BLUE lightning; with isAoe it also arcs to the
  /// enemies next to the target.
  void _mageBlueLightning(Unit unit, Enemy target) {
    target.takeDamage(unit.damage);
    effects.add(BattleEffect(
      kind: BattleEffectKind.blueBolt,
      x: unit.x,
      y: unit.y,
      x2: target.x,
      y2: target.y,
      life: 0.35,
      seed: _rng.nextInt(1 << 20),
    ));
    if (unit.isAoe) {
      var arcs = 0;
      for (final other in TargetingHelper.enemiesWithinRadius(target.x, target.y, 1.4, enemies)) {
        if (other.id == target.id || arcs >= 2) continue;
        other.takeDamage((unit.damage * 0.5).round());
        effects.add(BattleEffect(
          kind: BattleEffectKind.blueBolt,
          x: target.x,
          y: target.y,
          x2: other.x,
          y2: other.y,
          life: 0.3,
          seed: _rng.nextInt(1 << 20),
        ));
        arcs++;
      }
    }
  }

  /// Dragon / Phoenix: a jet of fire breathed from the mouth onto the target.
  /// Instant damage; the flames also scorch the enemies around the target.
  void _dragonFireBreath(Unit unit, Enemy target) {
    target.takeDamage(unit.damage);
    for (final other in TargetingHelper.enemiesWithinRadius(target.x, target.y, 1.4, enemies)) {
      if (other.id != target.id) other.takeDamage((unit.damage * 0.5).round());
    }
    effects.add(BattleEffect(
      kind: BattleEffectKind.fireBreath,
      x: unit.x,
      y: unit.y,
      x2: target.x,
      y2: target.y,
      life: 0.75,
      seed: _rng.nextInt(1 << 20),
      airborne: unit.isAirStriker,
      facingLeft: unit.facingLeft,
      creatureSize: UnitData.renderSizeFor(unit.type),
    ));
  }

  /// Elf Prince: calls a BARRAGE of fire down from the sky onto the enemy side:
  /// the target plus up to two enemies near it each get a column of fire,
  /// landing one after another. Each blast burns everything around it.
  void _elfPrinceSkyFire(Unit unit, Enemy target) {
    final spots = <List<double>>[
      [target.x, target.y, 1.0, 0.6],
    ];
    final near = TargetingHelper.enemiesWithinRadius(target.x, target.y, 3.0, enemies)
        .where((e) => e.id != target.id)
        .take(2)
        .toList();
    for (var i = 0; i < 2; i++) {
      if (i < near.length) {
        spots.add([near[i].x, near[i].y, 0.6, 0.85 + i * 0.25]);
      } else {
        spots.add([target.x + (i == 0 ? -1.0 : 1.0), target.y, 0.6, 0.85 + i * 0.25]);
      }
    }
    for (final s in spots) {
      final delay = s[3];
      _skyStrikes.add(_SkyStrike(
        x: s[0],
        y: s[1],
        damage: (unit.damage * s[2]).round(),
        delay: delay,
      ));
      effects.add(BattleEffect(
        kind: BattleEffectKind.skyFire,
        x: s[0],
        y: s[1],
        life: delay + 0.45,
        radius: delay, // how long the fire takes to fall
        seed: _rng.nextInt(1 << 20),
      ));
    }
  }

  void _tickSkyStrikes(double dt) {
    for (final s in _skyStrikes) {
      s.delay -= dt;
      if (s.delay > 0) continue;
      s.done = true;
      for (final e in TargetingHelper.enemiesWithinRadius(s.x, s.y, 1.3, enemies)) {
        final close = CollisionHelper.distance(s.x, s.y, e.x, e.y) <= 0.5;
        e.takeDamage(close ? s.damage : (s.damage * 0.5).round());
      }
    }
    _skyStrikes.removeWhere((s) => s.done);
  }

  /// Storm Knight: a bolt of electricity strikes the target instantly, then
  /// arcs on to every other soldier standing next to it.
  void _enemyLightning(Enemy enemy, Unit target) {
    target.takeDamage(enemy.damage);
    effects.add(BattleEffect(
      kind: BattleEffectKind.bolt,
      x: enemy.x,
      y: enemy.y,
      x2: target.x,
      y2: target.y,
      seed: _rng.nextInt(1 << 20),
    ));
    final chained = (enemy.damage * enemy.cleaveFraction).round();
    var arcs = 0;
    for (final other in TargetingHelper.unitsWithinRadius(target.x, target.y, enemy.cleaveRadius, units)) {
      if (other.id == target.id || arcs >= 3) continue;
      other.takeDamage(chained);
      effects.add(BattleEffect(
        kind: BattleEffectKind.bolt,
        x: target.x,
        y: target.y,
        x2: other.x,
        y2: other.y,
        seed: _rng.nextInt(1 << 20),
        life: 0.35,
      ));
      arcs++;
    }
  }

  /// Ember Hound: it barks, and a jet of fire shoots out of its mouth,
  /// scorching the target and anything right beside it.
  void _enemyFireBreath(Enemy enemy, Unit target) {
    target.takeDamage(enemy.damage);
    final splash = (enemy.damage * enemy.cleaveFraction).round();
    for (final other in TargetingHelper.unitsWithinRadius(target.x, target.y, enemy.cleaveRadius, units)) {
      if (other.id != target.id) other.takeDamage(splash);
    }
    effects.add(BattleEffect(kind: BattleEffectKind.bark, x: enemy.x, y: enemy.y, life: 0.6));
    effects.add(BattleEffect(
      kind: BattleEffectKind.fireJet,
      x: enemy.x,
      y: enemy.y,
      x2: target.x,
      y2: target.y,
      life: 0.45,
      seed: _rng.nextInt(1 << 20),
    ));
  }

  static const int _maxStormZones = 8;

  /// Storm Caller: conjures a storm cell on top of your army. After a short
  /// warning it rains lightning on everything inside for a few seconds.
  void _enemySummonStorm(Enemy enemy, double tx, double ty) {
    if (stormZones.length >= _maxStormZones) return;
    stormZones.add(StormZone(
      x: tx + (_rng.nextDouble() - 0.5) * 0.6,
      y: ty + (_rng.nextDouble() - 0.5) * 0.4,
      radius: 1.7,
      tickDamage: max(1, (enemy.damage * 0.3).round()),
      seed: _rng.nextInt(1 << 20),
    ));
    // The Storm Caller raises his hand: storm energy gathers in his palm and
    // streams out to the spot where the storm cell forms.
    effects.add(BattleEffect(
      kind: BattleEffectKind.stormCast,
      x: enemy.x,
      y: enemy.y,
      x2: tx,
      y2: ty,
      life: 0.9,
      seed: _rng.nextInt(1 << 20),
    ));
  }

  /// Thunder Titan: hurls a flaming boulder (it starts small and swells as it
  /// flies) at a soldier, or at the castle once nothing else is in range.
  void _enemyThrowFireStone(Enemy enemy, ProjectileTargetKind kind, Unit? target) {
    projectiles.add(Projectile(
      id: 'proj_${_projectileIdCounter++}',
      spriteName: 'fire_stone',
      targetKind: kind,
      targetUnitId: target?.id,
      damage: enemy.damage,
      speed: 6.0,
      x: enemy.x,
      y: enemy.y,
      effect: ProjectileEffect.splash,
      effectMagnitude: enemy.cleaveRadius,
      splashFraction: enemy.cleaveFraction,
    ));
  }

  /// Advances every storm cell: after its warning time it damages everything
  /// inside every 0.5s and drops visible lightning strikes.
  void _tickStormZones(double dt) {
    for (final z in stormZones) {
      z.age += dt;
      if (!z.isActive || z.expired) continue;
      z.tickTimer -= dt;
      while (z.tickTimer <= 0) {
        z.tickTimer += 0.5;
        for (final u in TargetingHelper.unitsWithinRadius(z.x, z.y, z.radius, units)) {
          u.takeDamage(z.tickDamage);
        }
        if (!playerCastle.isDestroyed &&
            CollisionHelper.distance(z.x, z.y, playerCastle.x, playerCastle.y) <= z.radius + 1.0) {
          playerCastle.takeDamage((z.tickDamage * 0.6).round());
        }
        _cue(SoundCue.thunder);
        final a = _rng.nextDouble() * 2 * pi;
        final r = _rng.nextDouble() * z.radius * 0.85;
        effects.add(BattleEffect(
          kind: BattleEffectKind.stormStrike,
          x: z.x + cos(a) * r,
          y: z.y + sin(a) * r * 0.6,
          life: 0.35,
          seed: _rng.nextInt(1 << 20),
        ));
      }
    }
    stormZones.removeWhere((z) => z.expired);
  }

  void _tickEffects(double dt) {
    for (final e in effects) {
      e.age += dt;
    }
    effects.removeWhere((e) => e.expired);
  }

  /// Magician: every few seconds heals every wounded ally (itself included)
  /// standing close by for 12% of their max HP.
  void _tickHealer(Unit healer, double dt) {
    healer.healTimer -= dt;
    if (healer.healTimer > 0) return;
    var healedAny = false;
    for (final ally in TargetingHelper.unitsWithinRadius(healer.x, healer.y, 2.6, units)) {
      if (!ally.alive || ally.hp >= ally.maxHp) continue;
      ally.hp = min(ally.maxHp, ally.hp + max(1, (ally.maxHp * 0.12).round()));
      healedAny = true;
    }
    if (healer.hp < healer.maxHp) {
      healer.hp = min(healer.maxHp, healer.hp + max(1, (healer.maxHp * 0.12).round()));
      healedAny = true;
    }
    if (healedAny) {
      _cue(SoundCue.healChime);
      effects.add(BattleEffect(
        kind: BattleEffectKind.heal,
        x: healer.x,
        y: healer.y,
        radius: 2.6,
        life: 0.8,
      ));
    }
    healer.healTimer = healedAny ? 2.5 : 0.5;
  }

  /// Only spawns tower shots. Advancing/resolving every projectile (tower,
  /// unit-arrow, or enemy-arrow alike) happens once, uniformly, in
  /// [_advanceProjectiles] below.
  void _fireTowerProjectiles(double dt) {
    for (final tower in towers) {
      final def = TowerData.defFor(tower.type);
      final stat = def.statAt(tower.level);
      tower.attackCooldown = max(0, tower.attackCooldown - dt);
      if (tower.attackCooldown > 0) continue;

      final target = TargetingHelper.bestTowerTarget(tower, enemies, stat.range);
      if (target == null) continue;

      tower.currentTargetEnemyId = target.id;
      tower.attackCooldown = stat.attackIntervalSeconds;
      projectiles.add(Projectile(
        id: 'proj_${_projectileIdCounter++}',
        spriteName: def.projectileSpriteName,
        targetKind: ProjectileTargetKind.enemy,
        sourceTowerId: tower.id,
        targetEnemyId: target.id,
        damage: stat.damage,
        speed: 12.0,
        x: tower.x,
        y: tower.y,
        effect: stat.effect,
        effectMagnitude: stat.effectMagnitude,
        effectDuration: stat.effectDuration,
        chainCount: stat.chainCount,
      ));
    }
  }

  /// A player archer's arrow, homing on the enemy it was aimed at. Damage
  /// (and, for the rare AoE unit, splash) only lands once the arrow arrives
  /// -- see _resolveProjectileImpact -- not the instant it's fired.
  void _fireUnitArrow(Unit unit, Enemy target) {
    projectiles.add(Projectile(
      id: 'proj_${_projectileIdCounter++}',
      spriteName: unit.type == UnitType.phoenix
          ? 'projectile_fireball'
          : (unit.type == UnitType.magician ? 'projectile_magic_ball' : 'projectile_arrow'),
      targetKind: ProjectileTargetKind.enemy,
      targetEnemyId: target.id,
      damage: unit.damage,
      speed: GameBalance.arrowProjectileSpeed,
      x: unit.x,
      y: unit.y,
      effect: (unit.isAoe || unit.type == UnitType.magician) ? ProjectileEffect.splash : ProjectileEffect.none,
      effectMagnitude: unit.type == UnitType.magician ? 1.3 : (unit.isAoe ? 1.0 : 0),
    ));
  }

  /// A skeleton archer's arrow fired back at the unit currently engaging it.
  void _fireEnemyArrowAtUnit(Enemy enemy, Unit target) {
    projectiles.add(Projectile(
      id: 'proj_${_projectileIdCounter++}',
      spriteName: 'projectile_arrow',
      targetKind: ProjectileTargetKind.unit,
      targetUnitId: target.id,
      damage: enemy.damage,
      speed: GameBalance.arrowProjectileSpeed,
      x: enemy.x,
      y: enemy.y,
    ));
  }

  /// A skeleton archer's arrow fired at the player's castle once it has
  /// slipped past every unit and settled within its own range of the wall.
  void _fireEnemyArrowAtCastle(Enemy enemy) {
    projectiles.add(Projectile(
      id: 'proj_${_projectileIdCounter++}',
      spriteName: 'projectile_arrow',
      targetKind: ProjectileTargetKind.castle,
      damage: enemy.damage,
      speed: GameBalance.arrowProjectileSpeed,
      x: enemy.x,
      y: enemy.y,
    ));
  }

  /// Moves every live projectile toward its target one step, resolving the
  /// hit once it arrives. Handles all three target kinds uniformly so tower
  /// shots, player arrows, and enemy arrows all fly and land the same way.
  void _advanceProjectiles(double dt) {
    for (final projectile in projectiles) {
      if (!projectile.alive) continue;

      double targetX;
      double targetY;
      switch (projectile.targetKind) {
        case ProjectileTargetKind.enemy:
          final target = enemies.where((e) => e.id == projectile.targetEnemyId).firstOrNull;
          if (target == null || !target.alive || target.charmed) {
            projectile.alive = false;
            continue;
          }
          targetX = target.x;
          targetY = target.y;
          break;
        case ProjectileTargetKind.unit:
          final target = units.where((u) => u.id == projectile.targetUnitId).firstOrNull;
          if (target == null || !target.alive) {
            // A fire stone whose target just died still comes down and blasts.
            if (projectile.effect == ProjectileEffect.splash) _splashOnPlayerSide(projectile);
            projectile.alive = false;
            continue;
          }
          targetX = target.x;
          targetY = target.y;
          break;
        case ProjectileTargetKind.castle:
          if (playerCastle.isDestroyed) {
            projectile.alive = false;
            continue;
          }
          targetX = playerCastle.x;
          targetY = playerCastle.y;
          break;
      }

      final d = CollisionHelper.distance(projectile.x, projectile.y, targetX, targetY);
      if (projectile.travelTotal <= 0) projectile.travelTotal = max(d, 0.001);
      projectile.progress = (1 - d / projectile.travelTotal).clamp(0.0, 1.0);
      // Also arrive when this step would reach the target: at 3x a step is longer
      // than the hit radius and the arrow used to circle around it forever.
      if (d <= 0.3 || d <= projectile.speed * dt) {
        _resolveProjectileImpact(projectile);
        projectile.alive = false;
      } else {
        final dx = targetX - projectile.x;
        final dy = targetY - projectile.y;
        final len = max(0.0001, d);
        projectile.x += (dx / len) * projectile.speed * dt;
        projectile.y += (dy / len) * projectile.speed * dt;
      }
    }
  }

  void _resolveProjectileImpact(Projectile projectile) {
    switch (projectile.targetKind) {
      case ProjectileTargetKind.enemy:
        final target = enemies.where((e) => e.id == projectile.targetEnemyId).firstOrNull;
        if (target != null && target.alive && !target.charmed) {
          CombatHelper.resolveProjectileHit(projectile, target, enemies);
          if (projectile.spriteName == 'projectile_magic_ball') {
            effects.add(BattleEffect(
              kind: BattleEffectKind.magicBurst,
              x: target.x,
              y: target.y,
              radius: 1.3,
              life: 0.5,
              seed: _rng.nextInt(1 << 20),
            ));
          }
        }
        break;
      case ProjectileTargetKind.unit:
        final target = units.where((u) => u.id == projectile.targetUnitId).firstOrNull;
        if (target != null && target.alive) target.takeDamage(projectile.damage);
        _splashOnPlayerSide(projectile);
        break;
      case ProjectileTargetKind.castle:
        if (!playerCastle.isDestroyed) playerCastle.takeDamage(projectile.damage);
        _splashOnPlayerSide(projectile);
        break;
    }
  }

  /// Blast from an enemy projectile (Thunder Titan's fire stone): hurts every
  /// soldier around the impact point and shows an explosion.
  void _splashOnPlayerSide(Projectile p) {
    if (p.effect != ProjectileEffect.splash || p.effectMagnitude <= 0) return;
    _cue(SoundCue.explosion);
    final splash = (p.damage * p.splashFraction).round();
    for (final u in TargetingHelper.unitsWithinRadius(p.x, p.y, p.effectMagnitude, units)) {
      u.takeDamage(splash);
    }
    effects.add(BattleEffect(
      kind: BattleEffectKind.explosion,
      x: p.x,
      y: p.y,
      radius: p.effectMagnitude,
      life: 0.55,
      seed: _rng.nextInt(1 << 20),
    ));
  }

  void _tickStatusEffects(double dt) {
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      CombatHelper.tickBurn(enemy, dt);
      CombatHelper.tickSlow(enemy, dt);
    }
  }

  void _cleanupDead() {
    for (final u in units) {
      if (u.alive) continue;
      switch (u.type) {
        case UnitType.phoenix:
          _cue(SoundCue.phoenixCry);
          break;
        case UnitType.dragon:
          _cue(SoundCue.dragonRoar);
          break;
        case UnitType.pandaWarrior:
          _cue(SoundCue.pandaRoar);
          break;
        default:
          _cue(SoundCue.hitThud);
      }
    }
    units.removeWhere((u) => !u.alive);
    for (final e in enemies) {
      if (!e.alive) {
        switch (e.type) {
          case EnemyType.lizard:
            _cue(SoundCue.lizardRoar);
            break;
          case EnemyType.monster:
            _cue(SoundCue.monsterGrowl);
            break;
          case EnemyType.thunderTitan:
            _cue(SoundCue.titanRoar);
            _cue(SoundCue.explosion);
            break;
          case EnemyType.blackDragon:
            _cue(SoundCue.dragonRoar);
            _cue(SoundCue.explosion);
            break;
          case EnemyType.goblin:
            _cue(SoundCue.goblinHit);
            break;
          default:
            _cue(SoundCue.hitThud);
        }
      }
      if (!e.alive && e.charmed) continue; // a fading traitor: no kill, no reward
      if (!e.alive) {
        enemiesKilled++;
        if (isEndless) {
          final pts = EnemyData.defFor(e.type).coinReward * GameBalance.scorePerCoinReward;
          score += (pts * _endlessStatMultiplier).round();
        }
      }
      if (!e.alive && !e.isBoss) {
        coinsEarnedThisBattle += GameBalance.coinsPerEnemyKillBase;
      } else if (!e.alive && e.isBoss) {
        coinsEarnedThisBattle += GameBalance.coinsPerEnemyKillBase * 10;
      }
    }
    enemies.removeWhere((e) => !e.alive);
    projectiles.removeWhere((p) => !p.alive);
  }

  void _checkWaveProgress() {
    if (isEndless) return;
    final aliveFromCurrentWave = enemies.where((e) => !e.charmed).length; // charmed ones are on our side
    final advanced = waveManager.tryAdvanceWave(aliveFromCurrentWave);
    if (advanced) {
      coinsEarnedThisBattle += GameBalance.coinsPerWaveClearBase;
    }
  }

  void _checkWinLose() {
    if (status != BattleStatus.ongoing) return;
    if (playerCastle.isDestroyed) {
      status = BattleStatus.defeat;
      return;
    }
    if (!isEndless && waveManager.allWavesComplete && enemies.every((e) => e.charmed)) {
      status = BattleStatus.victory;
    }
  }

  BattleResult _resultFor(BattleStatus s) {
    final stars = level == null
        ? 0
        : (playerCastle.hpPercent * 100 >= level!.starThresholds ? 3 : playerCastle.hpPercent > 0.3 ? 2 : 1);
    return BattleResult(
      status: s,
      coinsEarned: s == BattleStatus.victory ? coinsEarnedThisBattle + (level?.coinReward ?? 0) : coinsEarnedThisBattle,
      diamondsEarned: s == BattleStatus.victory ? (level?.diamondReward ?? 0) : 0,
      starsEarned: s == BattleStatus.victory ? stars : 0,
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// An Elf Prince sky-fire waiting to land (see BattleEngine._elfPrinceSkyFire).
class _SkyStrike {
  final double x;
  final double y;
  final int damage;
  double delay;
  bool done = false;
  _SkyStrike({required this.x, required this.y, required this.damage, required this.delay});
}
