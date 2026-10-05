// The root Flame game. Its jobs: (1) call into StateProvider each frame so
// BattleEngine advances, (2) keep one render Component per live model
// (Unit/Enemy/Tower/Projectile), adding/removing components to match
// whatever BattleEngine's lists currently contain, (3) own the
// world-to-screen scaling (computed fresh from `size` every call, so the
// battlefield always uses the full window — no fixed-resolution black bars
// on wide screens — and stretches to fill whatever vertical room is left
// between the HUD and the bottom bar instead of sitting in a thin strip),
// and (4) drive the looping day/night clock that MapComponent and every
// sprite's ground shadow read from. No combat, movement, or targeting logic
// lives here — components just read model fields to draw.
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/game.dart';
import 'package:flame/components.dart';

import '../game_logic/state_provider.dart';
import '../game_logic/path_manager.dart';
import '../models/sound_cue.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';
import '../services/sprite_cleaner.dart';
import '../services/sprite_registry.dart';
import 'components/storm_fx_component.dart';
import 'components/castle_component.dart';
import 'components/enemy_component.dart';
import 'components/map_component.dart';
import 'components/path_component.dart';
import 'components/projectile_component.dart';
import 'components/tower_component.dart';
import 'components/unit_component.dart';

class KingdomWarsGame extends FlameGame {
  final StateProvider provider;

  // ---- World bounds (in PathManager's lane units) --------------------
  // Everything the battle ever draws falls inside this box: X covers the
  // castle through the far spawn edge (plus a little breathing room), Y
  // covers the unit tracks above the lane through the bottom tower row.
  // Extends a little past PathManager.battlefieldStartX so the widened
  // battlefield backdrop (which now starts behind the castle instead of
  // right at it — see PathManager.battlefieldMarginX) is fully visible with
  // a small breathing-room gap, instead of being clipped at the screen edge.
  static const double _worldXMin = PathManager.battlefieldStartX - 1.0;
  static const double _worldXMax = PathManager.laneLength + 0.5;
  static const double _worldYMin = -2.6;
  static const double _worldYMax = 6.6;

  // Screen-space room reserved for the overlay widgets that sit on top of
  // the canvas (BattleHud up top, the mode switch + troop/tower bar down
  // bottom) so the battlefield content doesn't render underneath them.
  static const double _topReserved = 92.0;
  static const double _bottomReserved = 150.0;
  static const double _sideMargin = 16.0;

  KingdomWarsGame({required this.provider});

  final Map<String, UnitComponent> _unitComponents = {};
  final Map<String, EnemyComponent> _enemyComponents = {};
  final Map<String, TowerComponent> _towerComponents = {};
  final Map<String, ProjectileComponent> _projectileComponents = {};

  late CastleComponent playerCastleComponent;

  /// How many screen pixels one lane unit occupies. Recomputed from the
  /// current window size every time (rather than a fixed constant) and
  /// kept uniform on both axes — using the tighter of the two available
  /// dimensions — so the battlefield grows to fill the screen without ever
  /// stretching sprites out of proportion.
  double get pixelsPerUnit {
    final w = size.x > 0 ? size.x : 800.0;
    final h = size.y > 0 ? size.y : 600.0;
    final availW = (w - _sideMargin * 2) / (_worldXMax - _worldXMin);
    final availH = (h - _topReserved - _bottomReserved) / (_worldYMax - _worldYMin);
    return math.max(18.0, math.min(availW, availH));
  }

  /// Pixel X for world x=0, centering the (now screen-filling) battlefield
  /// horizontally in whatever width is left after the side margins.
  double get screenOriginXOffset {
    final w = size.x > 0 ? size.x : 800.0;
    final contentWidth = (_worldXMax - _worldXMin) * pixelsPerUnit;
    final leftPad = math.max(_sideMargin, (w - contentWidth) / 2);
    return leftPad - _worldXMin * pixelsPerUnit;
  }

  /// Pixel Y for world y=0 (laneCenterY), centering the battlefield in the
  /// vertical band left between the HUD and the bottom bar.
  double get screenOriginYOffset {
    final h = size.y > 0 ? size.y : 600.0;
    final contentHeight = (_worldYMax - _worldYMin) * pixelsPerUnit;
    final availH = math.max(0.0, h - _topReserved - _bottomReserved);
    final topPad = _topReserved + math.max(0.0, (availH - contentHeight) / 2);
    return topPad - _worldYMin * pixelsPerUnit;
  }

  /// Where the sky ends and the tiled ground begins, a little above the
  /// topmost unit track — scales with the current layout instead of a
  /// fixed pixel value so it always sits in the right place.
  double get groundTop {
    final raw = screenOriginYOffset - 2.4 * pixelsPerUnit;
    return raw.clamp(size.y * 0.18, size.y * 0.6);
  }

  Vector2 worldToScreen(double x, double y) => Vector2(
        x * pixelsPerUnit + screenOriginXOffset,
        y * pixelsPerUnit + screenOriginYOffset,
      );

  // ---- Day/night cycle -------------------------------------------------
  // A single ever-running clock. The cycle repeats forever: no "pause at
  // noon" — day quietly gives way to dusk, dusk to night, night to dawn,
  // and back to day, on a loop for as long as a battle runs.
  double dayNightClock = 0.0;
  // Day lasts 2.5 minutes (150s), night lasts 2 minutes (120s) — 270s total
  // per full loop. _dayShare is derived from those two so the two numbers
  // above stay the single source of truth.
  static const double _dayDuration = 150.0;
  static const double _nightDuration = 120.0;
  static const double cycleDuration = _dayDuration + _nightDuration;
  static const double _dayShare = _dayDuration / cycleDuration;

  double get cyclePhase => (dayNightClock % cycleDuration) / cycleDuration;
  bool get isDaySegment => cyclePhase < _dayShare;

  /// 0 = full night, 1 = full day. Eases across sunrise/sunset instead of
  /// snapping so sky colors and shadows fade rather than cut.
  double get daylight {
    const t = 0.06;
    final p = cyclePhase;
    if (p < _dayShare - t) return 1.0;
    if (p < _dayShare + t) return 1 - ((p - (_dayShare - t)) / (2 * t));
    final wrapEnd = 1.0 - t;
    if (p < wrapEnd) return 0.0;
    return (p - wrapEnd) / t;
  }

  /// 0..1 progress of whichever body (sun or moon) is currently up, used to
  /// arc it across the sky and to scale shadow strength/direction.
  double get bodyProgress {
    if (isDaySegment) return cyclePhase / _dayShare;
    return (cyclePhase - _dayShare) / (1 - _dayShare);
  }

  /// Screen position of the current sun/moon, arcing from the left horizon
  /// up over the sky band and down to the right horizon.
  Vector2 sunMoonPosition(double skyWidth, double skyHeight) {
    final t = bodyProgress;
    final x = skyWidth * (0.08 + 0.84 * t);
    final arc = math.sin(t * math.pi);
    final y = skyHeight * 0.88 - arc * skyHeight * 0.72;
    return Vector2(x, y);
  }

  /// Ground-shadow opacity multiplier: strongest with the sun/moon high
  /// overhead, fading to nothing right at sunrise/sunset when the light is
  /// edge-on. Used by every battlefield component via shadow_helper.dart.
  double get shadowStrength {
    final arc = math.sin(bodyProgress * math.pi).clamp(0.0, 1.0);
    return 0.22 + 0.6 * arc;
  }

  /// -1..1 horizontal skew following the sun/moon's arc, so shadows lean
  /// away from the light source the way they would outdoors.
  double get shadowSkew => (0.5 - bodyProgress) * 0.9;

  @override
  Color backgroundColor() => const Color(0xFF0B1026);

  @override
  Future<void> onLoad() async {
    // Flame's default Images cache prefix is "assets/images/", but this
    // project's pubspec.yaml declares art directly under "assets/kenney/..."
    // (no "images" folder in between). Left at the default, every single
    // images.load() call below fails silently (caught in _preloadSprites)
    // and every component falls back to "no sprite" — which is why nothing
    // was rendering at all. Pointing the cache at "assets/" matches the
    // actual folder layout.
    images.prefix = 'assets/';

    await _preloadSprites();

    add(MapComponent(game: this));
    add(PathComponent(game: this));
    add(StormFxComponent(game: this));

    final battle = provider.gameEngine.activeBattle;
    playerCastleComponent = CastleComponent(castle: battle!.playerCastle, game: this);
    add(playerCastleComponent);

    // Battle cries: your special units call out one after another as the
    // fight begins (kept short and quiet — see SoundService).
    final types = {for (final u in battle.units) u.type};
    if (types.contains(UnitType.phoenix)) SoundService.instance.playCueDelayed(SoundCue.phoenixCry, 700);
    if (types.contains(UnitType.pandaWarrior)) SoundService.instance.playCueDelayed(SoundCue.pandaRoar, 1900);
    if (types.contains(UnitType.dragon)) SoundService.instance.playCueDelayed(SoundCue.dragonRoar, 3100);
  }

  /// Sprites whose PNGs have a lot of empty transparent padding: they are
  /// auto-cropped to their real content when loaded (see
  /// SpriteCleaner.trimToContent), so the characters fill their box.
  static const Set<String> _trimmedSprites = {
    'magician',
    'good_dragon',
    'black_dragon',
    'phoenix',
    'elf_prince',
    'panda_warrior',
    'storm_knight',
    'storm_caller',
    'thunder_titan',
    'ember_hound',
  };

  Future<void> _preloadSprites() async {
    final trimPaths = {for (final n in _trimmedSprites) SpriteRegistry.pathFor(n)};
    // Only load art that actually ships in the asset bundle. Many registry
    // entries are optional (fire_stone, tile_storm, elite units...) and the
    // game draws fallbacks for them, so skipping them avoids 404 console spam.
    Set<String>? available;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      available = manifest.listAssets().toSet();
    } catch (_) {
      available = null; // manifest unreadable: fall back to try-every-path
    }

    for (final path in SpriteRegistry.paths.values) {
      if (available != null && !available.contains(path)) continue;
      final fileName = path.split('/').last;
      try {
        final key = fileName == path ? path : path.replaceFirst('assets/', '');
        final img = await images.load(key);
        // Characters/towers/projectiles must never show a white box: if the
        // PNG has an opaque white/light backdrop, make it transparent.
        // (Map tiles are meant to be opaque, so they're skipped.)
        if (!path.contains('/tiles/') && !path.contains('/ui/')) {
          var out = await SpriteCleaner.removeWhiteBackground(img);
          if (path.contains('/scenery/') || path.contains('/effects/')) {
            // Mountains / trees / grass: exact crop so trees & tufts stand on
            // their bottom edge and mountains sit flush on the horizon.
            out = await SpriteCleaner.trimToContent(out, square: false);
          } else if (trimPaths.contains(path)) {
            out = await SpriteCleaner.trimToContent(out);
          }
          if (!identical(out, img)) images.add(key, out);
        }
      } catch (_) {
        // Missing art asset during development shouldn't crash the game.
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    dayNightClock += dt;
    provider.tickBattle(dt);
    _playBattleSounds();
    _syncComponents();
  }

  /// Hands every sound the engine queued this frame to SoundService.
  void _playBattleSounds() {
    final battle = provider.gameEngine.activeBattle;
    if (battle == null || battle.soundQueue.isEmpty) return;
    for (final cue in battle.soundQueue) {
      SoundService.instance.playCue(cue);
    }
    battle.soundQueue.clear();
  }

  void _syncComponents() {
    final battle = provider.gameEngine.activeBattle;
    if (battle == null) return;

    _syncMap<UnitComponent>(
      liveIds: battle.units.map((u) => u.id).toSet(),
      existing: _unitComponents,
      createFor: (id) {
        final unit = battle.units.firstWhere((u) => u.id == id);
        final c = UnitComponent(unit: unit, game: this);
        add(c);
        return c;
      },
    );

    _syncMap<EnemyComponent>(
      liveIds: battle.enemies.map((e) => e.id).toSet(),
      existing: _enemyComponents,
      createFor: (id) {
        final enemy = battle.enemies.firstWhere((e) => e.id == id);
        final c = EnemyComponent(enemy: enemy, game: this);
        add(c);
        return c;
      },
    );

    _syncMap<TowerComponent>(
      liveIds: battle.towers.map((t) => t.id).toSet(),
      existing: _towerComponents,
      createFor: (id) {
        final tower = battle.towers.firstWhere((t) => t.id == id);
        final c = TowerComponent(tower: tower, game: this);
        add(c);
        return c;
      },
    );

    _syncMap<ProjectileComponent>(
      liveIds: battle.projectiles.map((p) => p.id).toSet(),
      existing: _projectileComponents,
      createFor: (id) {
        final projectile = battle.projectiles.firstWhere((p) => p.id == id);
        final c = ProjectileComponent(projectile: projectile, game: this);
        add(c);
        return c;
      },
    );
  }

  /// Generic add/remove reconciliation: any id in [liveIds] not yet in
  /// [existing] gets created via [createFor]; any id in [existing] no longer
  /// in [liveIds] gets removed from the game and the map.
  void _syncMap<T extends Component>({
    required Set<String> liveIds,
    required Map<String, T> existing,
    required T Function(String id) createFor,
  }) {
    for (final id in liveIds) {
      existing.putIfAbsent(id, () => createFor(id));
    }
    final toRemove = existing.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in toRemove) {
      existing[id]?.removeFromParent();
      existing.remove(id);
    }
  }
}
