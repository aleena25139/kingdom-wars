// empire_defense_game.dart
// FLAME — RENDER ONLY. This is the top of the render tree. Its update()
// loop does NOT run game logic — it diffs `provider.engine`'s current
// towers/enemies/projectiles lists against the components already on
// screen and adds/removes components to match. GameEngine.tick() (driven
// by StateProvider's Ticker, entirely separate from this class) is the
// only place that ever mutates game state.

import 'package:flame/game.dart';

import '../game_logic/state_provider.dart';
import 'components/map_component.dart';
import 'components/path_component.dart';
import 'components/enemy_component.dart';
import 'components/tower_component.dart';
import 'components/projectile_component.dart';

class EmpireDefenseGame extends FlameGame {
  final StateProvider provider;

  EmpireDefenseGame(this.provider);

  final Map<String, EnemyComponent> _enemyComponents = {};
  final Map<String, TowerComponent> _towerComponents = {};
  final Map<String, ProjectileComponent> _projectileComponents = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (!provider.hasEngine) return;

    final level = provider.engine.level;
    await add(MapComponent(level));
    await add(PathComponent(level.pathPoints));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!provider.hasEngine) return;

    _syncTowers();
    _syncEnemies();
    _syncProjectiles();
  }

  void _syncTowers() {
    final engine = provider.engine;
    final currentIds = engine.towers.map((t) => t.id).toSet();

    _towerComponents.keys.where((id) => !currentIds.contains(id)).toList().forEach((id) {
      _towerComponents.remove(id)?.removeFromParent();
    });

    for (final tower in engine.towers) {
      final existing = _towerComponents[tower.id];
      final isSelected = provider.selectedTowerId == tower.id;
      if (existing == null) {
        final comp = TowerComponent(tower, showRange: isSelected);
        _towerComponents[tower.id] = comp;
        add(comp);
      } else {
        existing.showRange = isSelected;
      }
    }
  }

  void _syncEnemies() {
    final engine = provider.engine;
    final currentIds = engine.enemies.map((e) => e.id).toSet();

    _enemyComponents.keys.where((id) => !currentIds.contains(id)).toList().forEach((id) {
      _enemyComponents.remove(id)?.removeFromParent();
    });

    for (final enemy in engine.enemies) {
      if (!_enemyComponents.containsKey(enemy.id)) {
        final comp = EnemyComponent(enemy);
        _enemyComponents[enemy.id] = comp;
        add(comp);
      }
    }
  }

  void _syncProjectiles() {
    final engine = provider.engine;
    final currentIds = engine.projectiles.map((p) => p.id).toSet();

    _projectileComponents.keys.where((id) => !currentIds.contains(id)).toList().forEach((id) {
      _projectileComponents.remove(id)?.removeFromParent();
    });

    for (final proj in engine.projectiles) {
      if (!_projectileComponents.containsKey(proj.id)) {
        final comp = ProjectileComponent(proj);
        _projectileComponents[proj.id] = comp;
        add(comp);
      }
    }
  }

  /// Called by GameScreen when the player loads a new level, so stale
  /// components from a previous run don't linger.
  void resetForNewLevel() {
    for (final c in _enemyComponents.values) {
      c.removeFromParent();
    }
    for (final c in _towerComponents.values) {
      c.removeFromParent();
    }
    for (final c in _projectileComponents.values) {
      c.removeFromParent();
    }
    _enemyComponents.clear();
    _towerComponents.clear();
    _projectileComponents.clear();
  }
}
