// Maps logical sprite names (used throughout models/game_logic) to their
// asset paths, so rendering code never hardcodes a path string. Flame
// components look up sprites here by the `spriteName` field on each model.

class SpriteRegistry {
  SpriteRegistry._();

  static const Map<String, String> paths = {
    // --- Good units ---
    'knight': 'assets/kenney/units/knight.png',
    'archer': 'assets/kenney/units/archer.png',
    'mage': 'assets/kenney/units/mage.png',
    'good_dragon': 'assets/kenney/units/good_dragon.png',
    // Panda Warrior: fights with kung-fu himself (flying kick, spin kick,
    // palm flurry — see UnitComponent._kungFuMove).
    'panda_warrior': 'assets/kenney/units/panda_warrior.png',
    // Elite units. Until their PNGs exist a tinted stand-in is drawn (see
    // UnitDef.fallbackSprite).
    'elf_prince': 'assets/kenney/units/elf_prince.png',
    'magician': 'assets/kenney/units/magician.png',
    'phoenix': 'assets/kenney/units/phoenix.png',

    // Optional VFX sprite: a bright glow/light-burst that flashes at the
    // Knight's sword tip on every hit (see UnitComponent._renderSwordLight).
    // Not shipped yet — until this file exists, UnitComponent draws a
    // procedurally-generated glow instead, so the effect still works with
    // or without the art. Placed under units/ (already-declared folder),
    // same trick as 'unit_arrow' below.
    'sword_light': 'assets/kenney/units/sword_light.png',

    // Legacy: the old summoned-Panda VFX sprite. No longer used now that
    // the Panda Warrior does his own kung-fu; safe to delete the file.
    'panda_summon': 'assets/kenney/units/panda_summon.png',

    // --- Evil units ---
    'goblin': 'assets/kenney/enemies/goblin.png',
    'skeleton': 'assets/kenney/enemies/skeleton.png',
    'skeleton_archer': 'assets/kenney/enemies/skeleton_archer.png',
    'lizard': 'assets/kenney/enemies/lizard.png',
    'monster': 'assets/kenney/enemies/monster.png',
    'orc': 'assets/kenney/enemies/orc.png',
    'dark_knight': 'assets/kenney/enemies/dark_knight.png',
    'dark_dragon': 'assets/kenney/enemies/dark_dragon.png',
    'boss': 'assets/kenney/enemies/boss.png',
    // Bad dragon (black). Put your ludo.ai PNG at this path; until it exists
    // the good dragon's art is drawn in black instead (EnemyDef.fallbackSprite).
    'black_dragon': 'assets/kenney/enemies/black_dragon.png',
    // Thunderstorm chapter enemies (until these PNGs exist, EnemyComponent
    // shows a tinted stand-in — see EnemyDef.fallbackSprite).
    'storm_knight': 'assets/kenney/enemies/storm_knight.png',
    'ember_hound': 'assets/kenney/enemies/ember_hound.png',
    'storm_caller': 'assets/kenney/enemies/storm_caller.png',
    'thunder_titan': 'assets/kenney/enemies/thunder_titan.png',

    // --- Towers (base sprite; upgrade tiers append _lvl2 / _lvl3) ---
    'tower_cannon': 'assets/kenney/towers/cannon.png',
    'tower_cannon_lvl2': 'assets/kenney/towers/cannon_lvl2.png',
    'tower_cannon_lvl3': 'assets/kenney/towers/cannon_lvl3.png',
    'tower_archer': 'assets/kenney/towers/archer.png',
    'tower_archer_lvl2': 'assets/kenney/towers/archer_lvl2.png',
    'tower_archer_lvl3': 'assets/kenney/towers/archer_lvl3.png',
    'tower_mage': 'assets/kenney/towers/mage.png',
    'tower_mage_lvl2': 'assets/kenney/towers/mage_lvl2.png',
    'tower_mage_lvl3': 'assets/kenney/towers/mage_lvl3.png',
    'tower_flamethrower': 'assets/kenney/towers/flamethrower.png',
    'tower_flamethrower_lvl2': 'assets/kenney/towers/flamethrower_lvl2.png',
    'tower_flamethrower_lvl3': 'assets/kenney/towers/flamethrower_lvl3.png',
    'tower_sniper': 'assets/kenney/towers/sniper.png',
    'tower_sniper_lvl2': 'assets/kenney/towers/sniper_lvl2.png',
    'tower_sniper_lvl3': 'assets/kenney/towers/sniper_lvl3.png',
    'tower_tesla': 'assets/kenney/towers/tesla.png',
    'tower_tesla_lvl2': 'assets/kenney/towers/tesla_lvl2.png',
    'tower_tesla_lvl3': 'assets/kenney/towers/tesla_lvl3.png',

    // --- Buildings ---
    'castle_evil': 'assets/kenney/buildings/castle_evil.png',

    // --- Projectiles ---
    'projectile_arrow': 'assets/kenney/towers/projectile_arrow.png',
    'projectile_cannonball': 'assets/kenney/towers/projectile_cannonball.png',
    'projectile_fireball': 'assets/kenney/towers/projectile_fireball.png',
    'projectile_bolt': 'assets/kenney/towers/projectile_bolt.png',
    // Magician's magic ball. Optional art: drawn in code when the file is absent.
    'projectile_magic_ball': 'assets/kenney/effects/magic_ball.png',
    // Hero power effects (all optional - drawn in code when missing).
    'fx_fire_breath': 'assets/kenney/effects/fire_breath.png',
    'fx_fire_burst': 'assets/kenney/effects/fire_burst.png',
    'fx_sky_fire': 'assets/kenney/effects/sky_fire.png',
    'fx_magic_burst': 'assets/kenney/effects/magic_burst.png',
    // Thunder Titan's boulder. Optional art: without the file it's drawn in code
    // (a burning rock that starts small and swells as it flies).
    'fire_stone': 'assets/kenney/towers/fire_stone.png',
    // Custom-design arrow, shared by the archer unit and the skeleton
    // archer enemy (both fire the same arrow at each other / the castle).
    // Placed under units/ (an already-declared asset folder) rather than a
    // new projectiles/ folder, so no pubspec.yaml change is needed.
    'unit_arrow': 'assets/kenney/units/arrow.png',

    // --- Map / tiles ---
    'tile_grass': 'assets/kenney/tiles/grass.png',
    'tile_path': 'assets/kenney/tiles/path.png',
    'tile_snow': 'assets/kenney/tiles/snow.png',
    'tile_lava': 'assets/kenney/tiles/lava.png',
    // Thunderstorm chapter ground (scorched, rain-soaked). Optional: without
    // the file the map paints a procedural charred ground instead.
    'tile_storm': 'assets/kenney/tiles/storm.png',

    // --- Scenery (all optional; drawn procedurally when a file is missing) ---
    'scenery_mountains_green': 'assets/kenney/scenery/mountains_green.png',
    'scenery_mountains_snow': 'assets/kenney/scenery/mountains_snow.png',
    'scenery_mountains_lava': 'assets/kenney/scenery/mountains_lava.png',
    'scenery_mountains_storm': 'assets/kenney/scenery/mountains_storm.png',
    'scenery_tree_green_1': 'assets/kenney/scenery/tree_green_1.png',
    'scenery_tree_green_2': 'assets/kenney/scenery/tree_green_2.png',
    'scenery_tree_green_3': 'assets/kenney/scenery/tree_green_3.png',
    'scenery_tree_snow_1': 'assets/kenney/scenery/tree_snow_1.png',
    'scenery_tree_snow_2': 'assets/kenney/scenery/tree_snow_2.png',
    'scenery_tree_burnt_1': 'assets/kenney/scenery/tree_burnt_1.png',
    'scenery_tree_burnt_2': 'assets/kenney/scenery/tree_burnt_2.png',
    'scenery_grass_1': 'assets/kenney/scenery/grass_1.png',
    'scenery_grass_2': 'assets/kenney/scenery/grass_2.png',
    'scenery_grass_3': 'assets/kenney/scenery/grass_3.png',
    'scenery_grass_snow': 'assets/kenney/scenery/grass_snow.png',
    'scenery_grass_dry': 'assets/kenney/scenery/grass_dry.png',

    // --- UI ---
    'coin': 'assets/kenney/ui/coin.png',
    'diamond': 'assets/kenney/ui/diamond.png',
    'star': 'assets/kenney/ui/star.png',
    'chest_common': 'assets/kenney/ui/chest_common.png',
    'chest_rare': 'assets/kenney/ui/chest_rare.png',
    'chest_legendary': 'assets/kenney/ui/chest_legendary.png',
  };

  static String pathFor(String name) {
    final path = paths[name];
    assert(path != null, 'SpriteRegistry: no sprite registered for "$name"');
    return path ?? paths['tile_grass']!; // safe fallback so a missing key never crashes render
  }

  /// Path for one of the 100 castle designs x 7 build stages (700 images
  /// total). Not in the static [paths] map — computed on demand so the game
  /// doesn't have to hardcode/preload 700 entries. See CastleArtData for the
  /// level -> (castleNumber, stageNumber) mapping.
  /// Frozen Pass (ice chapter) castle art: 7 build stages, same idea as the
  /// normal castles. Files: ice_castle_stage_1.png ... ice_castle_stage_7.png
  /// in assets/kenney/buildings/castles/. The stage follows the player's
  /// castle level (every upgrade = next stage, loops after 7).
  static String iceCastlePathForStage(int stageNumber) =>
      'assets/kenney/buildings/castles/ice_castle_stage_$stageNumber.png';

  /// Old single-image fallback (used only if a stage file is missing).
  static const String iceCastlePath = 'assets/kenney/buildings/castles/ice_castle.png';

  static String pathForCastle(int castleNumber, int stageNumber) =>
      'assets/kenney/buildings/castles/castle_${castleNumber}_stage_$stageNumber.png';
}
