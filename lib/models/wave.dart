// Describes a single wave: which enemy types spawn, in what order, and how
// far apart. WaveManager reads a Wave to schedule spawns; it doesn't hold
// any live battlefield state itself (that lives on Enemy instances).
import 'enemy.dart';

class WaveSpawnEntry {
  final EnemyType enemyType;
  final double delayAfterPreviousSeconds;

  const WaveSpawnEntry({
    required this.enemyType,
    required this.delayAfterPreviousSeconds,
  });
}

class Wave {
  final int waveNumber;
  final bool isBossWave;
  final List<WaveSpawnEntry> spawnEntries;
  final double statMultiplier; // applied on top of base enemy stats (endless scaling)

  const Wave({
    required this.waveNumber,
    required this.spawnEntries,
    this.isBossWave = false,
    this.statMultiplier = 1.0,
  });

  int get totalEnemyCount => spawnEntries.length;
}
