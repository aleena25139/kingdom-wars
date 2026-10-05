// Applies the actual effects of an attack: single-target damage, splash
// (AoE) damage, tesla-style chain lightning, mage slow, flamethrower burn.
// Called by BattleEngine each tick once TargetingHelper has already decided
// who's fighting whom.
import '../models/enemy.dart';
import '../models/unit.dart';
import '../models/tower.dart';
import '../constants/tower_data.dart';
import '../models/projectile.dart';
import 'targeting_helper.dart';

class CombatHelper {
  CombatHelper._();

  /// Resolves a tower's projectile landing on its target, applying damage
  /// plus whatever special effect that tower/level has.
  static int resolveProjectileHit(
    Projectile projectile,
    Enemy target,
    List<Enemy> allEnemies,
  ) {
    if (!target.alive) return 0;

    target.takeDamage(projectile.damage);
    int coinsFromKills = 0;

    switch (projectile.effect) {
      case ProjectileEffect.splash:
        final splashed = TargetingHelper.enemiesWithinRadius(
          target.x,
          target.y,
          projectile.effectMagnitude,
          allEnemies,
        );
        for (final e in splashed) {
          if (e.id == target.id) continue; // already hit directly above
          e.takeDamage((projectile.damage * 0.5).round());
        }
        break;
      case ProjectileEffect.slow:
        target.applySlow(projectile.effectMagnitude, projectile.effectDuration);
        break;
      case ProjectileEffect.burn:
        target.applyBurn(projectile.effectMagnitude.round(), projectile.effectDuration);
        break;
      case ProjectileEffect.chain:
        _applyChain(target, allEnemies, projectile.damage, projectile.chainCount);
        break;
      case ProjectileEffect.none:
        break;
    }
    return coinsFromKills;
  }

  static void _applyChain(
    Enemy firstTarget,
    List<Enemy> allEnemies,
    int baseDamage,
    int chainCount,
  ) {
    const chainRadius = 2.5;
    const chainDamageFalloff = 0.7; // each subsequent jump does 70% of the previous hit
    var currentDamage = baseDamage.toDouble();
    var lastX = firstTarget.x;
    var lastY = firstTarget.y;
    final alreadyHit = <String>{firstTarget.id};

    for (int i = 0; i < chainCount; i++) {
      final candidates = TargetingHelper.enemiesWithinRadius(lastX, lastY, chainRadius, allEnemies)
          .where((e) => !alreadyHit.contains(e.id))
          .toList();
      if (candidates.isEmpty) break;
      final next = candidates.first;
      currentDamage *= chainDamageFalloff;
      next.takeDamage(currentDamage.round());
      alreadyHit.add(next.id);
      lastX = next.x;
      lastY = next.y;
    }
  }

  /// Melee/ranged unit-vs-enemy exchange resolved once both are in range
  /// of each other (called symmetrically by BattleEngine).
  static void resolveUnitVsEnemy(Unit unit, Enemy enemy) {
    if (unit.attackCooldown <= 0 && unit.alive) {
      enemy.takeDamage(unit.damage);
      unit.attackCooldown = 1.0; // base 1 attack/sec; tune per-type later if needed
    }
    if (enemy.attackCooldown <= 0 && enemy.alive) {
      unit.takeDamage(enemy.damage);
      enemy.attackCooldown = 1.0;
    }
  }

  /// Applies burn-over-time damage; call once per tick for every enemy with
  /// an active burn.
  static void tickBurn(Enemy enemy, double dt) {
    if (enemy.burnDurationRemaining <= 0) return;
    enemy.takeDamage((enemy.burnDamagePerTick * dt).round());
    enemy.burnDurationRemaining -= dt;
    if (enemy.burnDurationRemaining <= 0) {
      enemy.burnDamagePerTick = 0;
    }
  }

  static void tickSlow(Enemy enemy, double dt) {
    if (enemy.slowDurationRemaining <= 0) return;
    enemy.slowDurationRemaining -= dt;
    if (enemy.slowDurationRemaining <= 0) {
      enemy.slowFactor = 0;
    }
  }

  static double towerAttackIntervalFor(Tower tower) =>
      TowerData.defFor(tower.type).statAt(tower.level).attackIntervalSeconds;
}
