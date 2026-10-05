// Static data for the Town module: the catalogue of everything the player can
// build (streets, houses, public buildings, parks, water, trains, LEGO, nature
// and decorations), the endless map addressing, and the town-level thresholds.
//
// Flow: win campaign levels -> unlock town pieces -> build them with COINS or
// DIAMONDS. Houses are always FREE. There is no tax system any more.
//
// The map is endless: tiles are addressed by (col,row) that may be negative.
// A tile key packs both numbers into one int (see [key]); [worldLimit] is only
// there so the packing can never overflow - nobody will walk 40,000 tiles.
import 'package:flutter/material.dart';

enum TownCategory { roads, houses, buildings, parks, water, trains, lego, farms, decor }

extension TownCategoryX on TownCategory {
  String get label {
    switch (this) {
      case TownCategory.roads:
        return 'Streets';
      case TownCategory.houses:
        return 'Houses';
      case TownCategory.buildings:
        return 'Buildings';
      case TownCategory.parks:
        return 'Parks';
      case TownCategory.water:
        return 'Water';
      case TownCategory.trains:
        return 'Trains';
      case TownCategory.lego:
        return 'Lego';
      case TownCategory.farms:
        return 'Fields';
      case TownCategory.decor:
        return 'Nature';
    }
  }

  IconData get icon {
    switch (this) {
      case TownCategory.roads:
        return Icons.add_road;
      case TownCategory.houses:
        return Icons.home;
      case TownCategory.buildings:
        return Icons.location_city;
      case TownCategory.parks:
        return Icons.park;
      case TownCategory.water:
        return Icons.water;
      case TownCategory.trains:
        return Icons.train;
      case TownCategory.lego:
        return Icons.extension;
      case TownCategory.farms:
        return Icons.grass;
      case TownCategory.decor:
        return Icons.local_florist;
    }
  }
}

class BuildingDef {
  final String id; // also the key TownArt uses to draw it
  final String name;
  final TownCategory category;
  final int coins; // price in coins (0 = free)
  final int diamonds; // price in diamonds (0 = none)
  final int unlockWins; // campaign levels that must be beaten first
  final int population; // citizens it adds
  final int happiness; // happiness it adds
  final String blurb;

  /// Ids of tiles this piece may be placed ON (it replaces them), e.g. a
  /// bridge goes on a river tile and a train goes on a rail tile.
  final List<String> placeOn;

  const BuildingDef({
    required this.id,
    required this.name,
    required this.category,
    required this.unlockWins,
    this.coins = 0,
    this.diamonds = 0,
    this.population = 0,
    this.happiness = 0,
    this.blurb = '',
    this.placeOn = const [],
  });

  bool get isFree => coins == 0 && diamonds == 0;
  bool get usesDiamonds => diamonds > 0;
  bool get isRoad => category == TownCategory.roads;

  /// Flat / cheap things can be "painted" by dragging a finger across the map.
  bool get dragPlaceable =>
      diamonds == 0 &&
      (id == 'road' ||
          id == 'cobble' ||
          id == 'plaza' ||
          id == 'river' ||
          id == 'rail' ||
          category == TownCategory.farms ||
          id == 'lego_plate' ||
          id.startsWith('lego_brick_') ||
          (category == TownCategory.decor && coins <= 60));
}

class TownData {
  TownData._();

  // ---- Endless map -----------------------------------------------------------
  /// Tiles run from -worldLimit to +worldLimit in both directions.
  static const int worldLimit = 40000;
  static const int _offset = 50000;
  static const int _stride = 100000;

  /// Fresh towns start around here (the camera also centres on existing builds).
  static const int homeCol = 0;
  static const int homeRow = 0;

  static bool inWorld(int col, int row) =>
      col >= -worldLimit && col <= worldLimit && row >= -worldLimit && row <= worldLimit;

  static int key(int col, int row) => (row + _offset) * _stride + (col + _offset);
  static int colOf(int key) => key % _stride - _offset;
  static int rowOf(int key) => key ~/ _stride - _offset;

  // Old saves used key = row * 100 + col on a 100 x 100 map. Those towns keep
  // their (col,row) positions - the new map simply continues in every direction.
  static const int _legacyKeyLimit = 10000000;

  static Map<int, String> migrateGrid(Map<int, String> g) {
    if (g.isEmpty) return g;
    for (final k in g.keys) {
      if (k >= _legacyKeyLimit) return g; // already the new format
    }
    return {
      for (final e in g.entries) key(e.key % 100, e.key ~/ 100): e.value,
    };
  }

  /// Refund when demolishing (fraction of the price, for coins and diamonds).
  static const double refundFraction = 0.5;

  static int refundCoins(BuildingDef d) => (d.coins * refundFraction).round();
  static int refundDiamonds(BuildingDef d) => (d.diamonds * refundFraction).floor();

  // Old saves had Bricks. They are turned into coins once, when the save loads.
  static const int coinsPerOldBrick = 5;

  // ---- Town levels -----------------------------------------------------------
  // score = population + happiness * 2 + number of buildings
  static const List<int> levelThresholds = [0, 25, 70, 140, 240, 380, 560, 800, 1100, 1500];
  static const List<String> levelNames = [
    'Camp',
    'Hamlet',
    'Village',
    'Small Town',
    'Town',
    'Big Town',
    'City',
    'Grand City',
    'Metropolis',
    'Royal Capital',
  ];
  static const int diamondsPerTownLevel = 5;

  static int levelForScore(int score) {
    var lvl = 0;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (score >= levelThresholds[i]) lvl = i;
    }
    return lvl;
  }

  // ---- Catalogue --------------------------------------------------------------
  // HOUSES ARE FREE. Everything else costs coins, a few special pieces cost
  // diamonds. unlockWins = campaign levels the player must have beaten.
  static const List<BuildingDef> all = [
    // ---------------- Streets ----------------
    BuildingDef(id: 'road', name: 'Dirt Road', category: TownCategory.roads, coins: 20, unlockWins: 0,
        blurb: 'Basic street. Connects to neighbouring roads. Drag to paint.'),
    BuildingDef(id: 'cobble', name: 'Cobble Street', category: TownCategory.roads, coins: 40, unlockWins: 1, happiness: 1,
        blurb: 'Nicer stone street.'),
    BuildingDef(id: 'plaza', name: 'Stone Plaza', category: TownCategory.roads, coins: 80, unlockWins: 3, happiness: 2,
        blurb: 'A paved square for gatherings.'),

    // ---------------- Houses (all free) ----------------
    BuildingDef(id: 'hut', name: 'Thatched Hut', category: TownCategory.houses, unlockWins: 0, population: 2,
        blurb: 'Wattle-and-daub hut with a straw roof. Free!'),
    BuildingDef(id: 'cottage', name: 'Timber Cottage', category: TownCategory.houses, unlockWins: 0, population: 4,
        blurb: 'Timber-framed cottage with a stone chimney. Free!'),
    BuildingDef(id: 'bungalow', name: 'Cosy Bungalow', category: TownCategory.houses, unlockWins: 1, population: 5,
        blurb: 'One-storey home with a little porch. Free!'),
    BuildingDef(id: 'brick_house', name: 'Stone House', category: TownCategory.houses, unlockWins: 2, population: 7,
        blurb: 'Sturdy stone house with a slate roof. Free!'),
    BuildingDef(id: 'townhouse', name: 'Townhouse', category: TownCategory.houses, unlockWins: 3, population: 9,
        blurb: 'Tall narrow house with a colourful front. Free!'),
    BuildingDef(id: 'villa', name: 'Manor House', category: TownCategory.houses, unlockWins: 5, population: 12, happiness: 2,
        blurb: 'A noble manor with a turret and banner. Free!'),
    BuildingDef(id: 'apartment', name: 'Tall Tenement', category: TownCategory.houses, unlockWins: 7, population: 28,
        blurb: 'Three-storey town house for many families. Free!'),
    BuildingDef(id: 'tower_block', name: 'Tower Block', category: TownCategory.houses, unlockWins: 10, population: 50,
        blurb: 'A big modern block of flats. Free!'),

    // ---------------- Buildings ----------------
    BuildingDef(id: 'bakery', name: 'Bakery', category: TownCategory.buildings, coins: 240, unlockWins: 1, happiness: 3,
        blurb: 'Fresh bread every morning.'),
    BuildingDef(id: 'cafe', name: 'Cafe', category: TownCategory.buildings, coins: 280, unlockWins: 2, happiness: 4,
        blurb: 'Tables outside, coffee inside.'),
    BuildingDef(id: 'market', name: 'Market', category: TownCategory.buildings, coins: 420, unlockWins: 3, happiness: 6,
        blurb: 'Busy stalls full of goods.'),
    BuildingDef(id: 'gas_station', name: 'Gas Station', category: TownCategory.buildings, coins: 360, unlockWins: 3, happiness: 3,
        blurb: 'Fuel up the cars.'),
    BuildingDef(id: 'inn', name: 'Inn', category: TownCategory.buildings, coins: 480, unlockWins: 4, happiness: 5, population: 2,
        blurb: 'Food, drink and a warm bed.'),
    BuildingDef(id: 'blacksmith', name: 'Blacksmith', category: TownCategory.buildings, coins: 460, unlockWins: 4, happiness: 4,
        blurb: 'Hammering all day long.'),
    BuildingDef(id: 'post_office', name: 'Post Office', category: TownCategory.buildings, coins: 500, unlockWins: 5, happiness: 5,
        blurb: 'Letters and parcels.'),
    BuildingDef(id: 'school', name: 'School', category: TownCategory.buildings, coins: 580, unlockWins: 5, happiness: 8,
        blurb: 'Children learn to read and count.'),
    BuildingDef(id: 'police', name: 'Police Station', category: TownCategory.buildings, coins: 620, unlockWins: 6, happiness: 8,
        blurb: 'Keeps the streets safe.'),
    BuildingDef(id: 'clinic', name: 'Clinic', category: TownCategory.buildings, coins: 660, unlockWins: 6, happiness: 9,
        blurb: 'Keeps the citizens healthy.'),
    BuildingDef(id: 'fire_station', name: 'Fire Station', category: TownCategory.buildings, coins: 700, unlockWins: 7, happiness: 8,
        blurb: 'Protects the town from fires.'),
    BuildingDef(id: 'cinema', name: 'Cinema', category: TownCategory.buildings, coins: 760, unlockWins: 8, happiness: 11,
        blurb: 'Movie night for everyone.'),
    BuildingDef(id: 'library', name: 'Library', category: TownCategory.buildings, coins: 760, unlockWins: 8, happiness: 10,
        blurb: 'Thousands of books.'),
    BuildingDef(id: 'hotel', name: 'Grand Hotel', category: TownCategory.buildings, coins: 1100, unlockWins: 10, happiness: 12, population: 6,
        blurb: 'Tall hotel with a shiny sign.'),
    BuildingDef(id: 'town_hall', name: 'Town Hall', category: TownCategory.buildings, coins: 1300, unlockWins: 9, happiness: 20,
        blurb: 'The heart of the town.'),
    BuildingDef(id: 'clock_tower', name: 'Clock Tower', category: TownCategory.buildings, diamonds: 10, unlockWins: 11, happiness: 14,
        blurb: 'Tall tower showing the time. Costs diamonds.'),

    // ---------------- Parks ----------------
    BuildingDef(id: 'garden', name: 'Flower Garden', category: TownCategory.parks, coins: 200, unlockWins: 1, happiness: 4,
        blurb: 'Hedges and colourful flowers.'),
    BuildingDef(id: 'fountain_small', name: 'Fountain', category: TownCategory.parks, coins: 300, unlockWins: 1, happiness: 6,
        blurb: 'Water sparkles in the sun.'),
    BuildingDef(id: 'playground', name: 'Playground', category: TownCategory.parks, coins: 380, unlockWins: 2, happiness: 9,
        blurb: 'Slide, swings and a sandbox.'),
    BuildingDef(id: 'pond', name: 'Duck Pond', category: TownCategory.parks, coins: 340, unlockWins: 3, happiness: 6,
        blurb: 'Quiet pond with lily pads.'),
    BuildingDef(id: 'basketball', name: 'Basketball Court', category: TownCategory.parks, coins: 520, unlockWins: 5, happiness: 9,
        blurb: 'Shoot some hoops.'),
    BuildingDef(id: 'pool', name: 'Swimming Pool', category: TownCategory.parks, coins: 640, unlockWins: 6, happiness: 11,
        blurb: 'Splash! Perfect for summer.'),
    BuildingDef(id: 'football', name: 'Football Ground', category: TownCategory.parks, coins: 620, unlockWins: 6, happiness: 12,
        blurb: 'Weekend matches!'),
    BuildingDef(id: 'carousel', name: 'Carousel', category: TownCategory.parks, coins: 800, unlockWins: 8, happiness: 12,
        blurb: 'Colourful horses go round and round.'),
    BuildingDef(id: 'fountain_grand', name: 'Grand Fountain', category: TownCategory.parks, diamonds: 8, unlockWins: 7, happiness: 14,
        blurb: 'Tiered fountain with tall jets. Costs diamonds.'),
    BuildingDef(id: 'ferris_wheel', name: 'Ferris Wheel', category: TownCategory.parks, diamonds: 12, unlockWins: 10, happiness: 18,
        blurb: 'See the whole town from the top. Costs diamonds.'),

    // ---------------- Water ----------------
    BuildingDef(id: 'river', name: 'River', category: TownCategory.water, coins: 30, unlockWins: 0, happiness: 1,
        blurb: 'Flowing water. Drag to paint a long river - it joins up by itself.'),
    BuildingDef(id: 'lake', name: 'Lake', category: TownCategory.water, coins: 120, unlockWins: 1, happiness: 3,
        blurb: 'A small blue lake with reeds.'),
    BuildingDef(id: 'bridge', name: 'Wooden Bridge', category: TownCategory.water, coins: 120, unlockWins: 0, happiness: 2,
        placeOn: ['river'],
        blurb: 'Put it ON a river tile to cross the water.'),
    BuildingDef(id: 'stone_bridge', name: 'Stone Bridge', category: TownCategory.water, coins: 320, unlockWins: 4, happiness: 4,
        placeOn: ['river'],
        blurb: 'Strong arched bridge. Put it ON a river tile.'),
    BuildingDef(id: 'boat', name: 'Sailboat', category: TownCategory.water, coins: 150, unlockWins: 2, happiness: 2,
        placeOn: ['river'],
        blurb: 'Bobs along. Put it ON a river tile.'),

    // ---------------- Trains ----------------
    BuildingDef(id: 'rail', name: 'Train Track', category: TownCategory.trains, coins: 40, unlockWins: 1,
        blurb: 'Rails connect to each other. Drag to lay a long track.'),
    BuildingDef(id: 'train_stop', name: 'Train Stop', category: TownCategory.trains, coins: 260, unlockWins: 2, happiness: 3,
        blurb: 'Small platform on the track (runs left-right).'),
    BuildingDef(id: 'signal', name: 'Rail Signal', category: TownCategory.trains, coins: 60, unlockWins: 2, happiness: 1,
        blurb: 'Red and green lights.'),
    BuildingDef(id: 'station', name: 'Train Station', category: TownCategory.trains, coins: 900, unlockWins: 5, happiness: 12,
        blurb: 'Big station building with a clock (runs left-right).'),
    BuildingDef(id: 'train_wagon', name: 'Train Wagon', category: TownCategory.trains, coins: 200, unlockWins: 4, happiness: 2,
        placeOn: ['rail'],
        blurb: 'Put it ON a track tile.'),
    BuildingDef(id: 'train', name: 'Steam Train', category: TownCategory.trains, diamonds: 6, unlockWins: 6, happiness: 8,
        placeOn: ['rail'],
        blurb: 'Puffing locomotive. Put it ON a track tile. Costs diamonds.'),

    // ---------------- Lego ----------------
    BuildingDef(id: 'lego_plate', name: 'Base Plate', category: TownCategory.lego, coins: 15, unlockWins: 0,
        blurb: 'Green plate with studs. Drag to cover the ground.'),
    BuildingDef(id: 'lego_brick_red', name: 'Red Brick', category: TownCategory.lego, coins: 30, unlockWins: 0, happiness: 1,
        blurb: 'Classic red brick.'),
    BuildingDef(id: 'lego_brick_blue', name: 'Blue Brick', category: TownCategory.lego, coins: 30, unlockWins: 0, happiness: 1,
        blurb: 'Classic blue brick.'),
    BuildingDef(id: 'lego_brick_yellow', name: 'Yellow Brick', category: TownCategory.lego, coins: 30, unlockWins: 1, happiness: 1,
        blurb: 'Classic yellow brick.'),
    BuildingDef(id: 'lego_brick_green', name: 'Green Brick', category: TownCategory.lego, coins: 30, unlockWins: 1, happiness: 1,
        blurb: 'Classic green brick.'),
    BuildingDef(id: 'lego_tree', name: 'Lego Tree', category: TownCategory.lego, coins: 60, unlockWins: 1, happiness: 2,
        blurb: 'A tree made of round bricks.'),
    BuildingDef(id: 'lego_figure', name: 'Lego Figure', category: TownCategory.lego, coins: 90, unlockWins: 2, happiness: 3,
        blurb: 'A smiling little minifigure.'),
    BuildingDef(id: 'lego_car', name: 'Lego Car', category: TownCategory.lego, coins: 140, unlockWins: 3, happiness: 4,
        blurb: 'Brick car with round wheels.'),
    BuildingDef(id: 'lego_house', name: 'Lego House', category: TownCategory.lego, coins: 260, unlockWins: 4, population: 6, happiness: 4,
        blurb: 'A house built from bricks. Citizens love it.'),
    BuildingDef(id: 'lego_tower', name: 'Lego Tower', category: TownCategory.lego, coins: 360, unlockWins: 6, happiness: 8,
        blurb: 'A tall tower of stacked bricks.'),
    BuildingDef(id: 'lego_castle', name: 'Lego Castle', category: TownCategory.lego, diamonds: 10, unlockWins: 9, happiness: 16,
        blurb: 'A whole castle made of bricks. Costs diamonds.'),

    // ---------------- Fields (drag a finger to paint big farms) ----------------
    BuildingDef(id: 'wheat_field', name: 'Wheat Field', category: TownCategory.farms, coins: 50, unlockWins: 0,
        blurb: 'Golden wheat swaying in the wind. Drag to paint a big field.'),
    BuildingDef(id: 'veg_field', name: 'Vegetable Patch', category: TownCategory.farms, coins: 60, unlockWins: 1,
        blurb: 'Rows of cabbages and carrots.'),
    BuildingDef(id: 'pasture', name: 'Pasture', category: TownCategory.farms, coins: 50, unlockWins: 1,
        blurb: 'Fenced meadow where sheep graze.'),

    // ---------------- Nature + decoration ----------------
    BuildingDef(id: 'tree', name: 'Oak Tree', category: TownCategory.decor, coins: 20, unlockWins: 0, happiness: 1,
        blurb: 'Shade and fresh air.'),
    BuildingDef(id: 'pine', name: 'Pine Tree', category: TownCategory.decor, coins: 20, unlockWins: 0, happiness: 1,
        blurb: 'Evergreen pine.'),
    BuildingDef(id: 'bush', name: 'Bush', category: TownCategory.decor, coins: 10, unlockWins: 0, happiness: 1,
        blurb: 'Round green bush with berries.'),
    BuildingDef(id: 'flowers', name: 'Flower Bed', category: TownCategory.decor, coins: 30, unlockWins: 0, happiness: 1,
        blurb: 'Bright little flowers.'),
    BuildingDef(id: 'rock', name: 'Rocks', category: TownCategory.decor, coins: 10, unlockWins: 0,
        blurb: 'A few mossy stones.'),
    BuildingDef(id: 'bench', name: 'Bench', category: TownCategory.decor, coins: 50, unlockWins: 1, happiness: 1,
        blurb: 'A place to rest.'),
    BuildingDef(id: 'lamp', name: 'Street Lamp', category: TownCategory.decor, coins: 60, unlockWins: 1, happiness: 1,
        blurb: 'Lights the street at night.'),
    BuildingDef(id: 'bus_stop', name: 'Bus Stop', category: TownCategory.decor, coins: 90, unlockWins: 2, happiness: 2,
        blurb: 'Wait for the bus here.'),
    BuildingDef(id: 'car', name: 'Car', category: TownCategory.decor, coins: 160, unlockWins: 2, happiness: 2,
        blurb: 'A little red car.'),
    BuildingDef(id: 'bus', name: 'Bus', category: TownCategory.decor, coins: 300, unlockWins: 4, happiness: 4,
        blurb: 'A yellow city bus.'),
    BuildingDef(id: 'well', name: 'Stone Well', category: TownCategory.decor, coins: 160, unlockWins: 2, happiness: 3,
        blurb: 'Fresh water for everyone.'),
    BuildingDef(id: 'statue', name: 'Hero Statue', category: TownCategory.decor, diamonds: 6, unlockWins: 6, happiness: 10,
        blurb: 'A knight who defended the kingdom. Costs diamonds.'),
    BuildingDef(id: 'windmill', name: 'Windmill', category: TownCategory.decor, diamonds: 8, unlockWins: 8, happiness: 8,
        blurb: 'Blades turning in the wind. Costs diamonds.'),
  ];

  static final Map<String, BuildingDef> _byId = {for (final b in all) b.id: b};

  static BuildingDef? byId(String id) => _byId[id];

  static List<BuildingDef> inCategory(TownCategory c) => all.where((b) => b.category == c).toList();

  // ---- Stats from a grid ---------------------------------------------------
  static int populationOf(Map<int, String> grid) {
    var n = 0;
    for (final id in grid.values) {
      n += byId(id)?.population ?? 0;
    }
    return n;
  }

  static int happinessOf(Map<int, String> grid) {
    var n = 0;
    for (final id in grid.values) {
      n += byId(id)?.happiness ?? 0;
    }
    return n;
  }

  static int scoreOf(Map<int, String> grid) =>
      populationOf(grid) + happinessOf(grid) * 2 + grid.length;
}
