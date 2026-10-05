// Drives enemy spawning for a battle: walks through a Level's Wave list,
// spawning each WaveSpawnEntry after its configured delay, and reports when
// a wave (and the whole level) is fully cleared so BattleEngine can grant
// rewards / advance / end the battle.
import '../constants/enemy_data.dart';
import '../models/enemy.dart';
import '../models/level.dart';
import '../models/wave.dart';
import 'path_manager.dart';

class WaveManager {
  final List<Wave> waves;
  int currentWaveIndex = 0;
  int _nextSpawnEntryIndex = 0;
  double _timeUntilNextSpawn = 0;
  int _spawnCounter = 0;
  bool waveFullySpawned = false;

  WaveManager(this.waves);

  factory WaveManager.forLevel(LevelDef level) => WaveManager(level.waves);

  bool get isLastWave => currentWaveIndex >= waves.length - 1;
  bool get allWavesComplete => currentWaveIndex >= waves.length;

  Wave? get currentWave =>
      currentWaveIndex < waves.length ? waves[currentWaveIndex] : null;

  int get currentWaveNumber => currentWave?.waveNumber ?? waves.length;
  int get totalWaves => waves.length;

  /// Advances spawn timers and returns any Enemy instances that should be
  /// added to the battlefield this tick.
  List<Enemy> tick(double dt) {
    final spawned = <Enemy>[];
    final wave = currentWave;
    if (wave == null) return spawned;

    if (waveFullySpawned) return spawned;

    _timeUntilNextSpawn -= dt;
    while (_timeUntilNextSpawn <= 0 && _nextSpawnEntryIndex < wave.spawnEntries.length) {
      final entry = wave.spawnEntries[_nextSpawnEntryIndex];
      spawned.add(_spawnEnemy(entry.enemyType, wave.statMultiplier));
      _nextSpawnEntryIndex++;
      if (_nextSpawnEntryIndex < wave.spawnEntries.length) {
        _timeUntilNextSpawn += wave.spawnEntries[_nextSpawnEntryIndex].delayAfterPreviousSeconds;
      } else {
        waveFullySpawned = true;
      }
    }
    return spawned;
  }

  Enemy _spawnEnemy(EnemyType type, double statMultiplier) {
    final def = EnemyData.defFor(type);
    final (x, y) = PathManager.enemySpawnPoint(_spawnCounter++);
    return Enemy(
      id: 'enemy_${DateTime.now().microsecondsSinceEpoch}_$_spawnCounter',
      type: type,
      spriteName: def.spriteName,
      maxHp: (def.hp * statMultiplier).round(),
      damage: (def.damage * statMultiplier).round(),
      baseSpeed: def.speed,
      isFlying: def.isFlying,
      isBoss: def.isBoss,
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

  /// Call once all enemies from the current wave have been defeated (checked
  /// by BattleEngine against its live enemy list) to move to the next wave.
  bool tryAdvanceWave(int aliveEnemiesFromThisWave) {
    if (waveFullySpawned && aliveEnemiesFromThisWave == 0) {
      currentWaveIndex++;
      _nextSpawnEntryIndex = 0;
      _timeUntilNextSpawn = 0;
      waveFullySpawned = false;
      return true;
    }
    return false;
  }
}
