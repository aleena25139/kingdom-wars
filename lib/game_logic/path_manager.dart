// Defines the 1D "lane" the battle plays out on: the player's castle sits at
// x=0 on the left, enemies stream in from the right edge of the lane and
// march toward it. There is no enemy castle — this is a pure defense
// layout. Player units spawn at the castle, walk out to a fixed defensive
// line partway down the lane, and hold that ground rather than marching all
// the way across; enemies that reach them get engaged there, any that slip
// past keep going until they hit the castle itself.
//
// A handful of parallel y-tracks keep multiple units/enemies spawned at the
// same time from rendering stacked on top of each other. All positions used
// by GameEngine/BattleEngine are expressed in these lane coordinates; Flame
// components convert to screen pixels.

class PathManager {
  PathManager._();

  static const double laneLength = 20.0; // world units, castle to the far spawn edge
  static const double playerCastleX = 0.0;
  static const double enemySpawnEdgeX = laneLength; // enemies stream in from here
  static const double laneCenterY = 0.0;

  /// How far behind the castle (world units, negative direction) the visible
  /// battlefield backdrop now extends. Previously the dark battlefield rect
  /// started exactly at playerCastleX, so half the castle sprite (~1.46
  /// units either side of x=0, see PathComponent) hung off its left edge
  /// onto the plain ground. Extending the backdrop this far back — enough to
  /// clear the castle's half-width plus a small gap — makes the field a
  /// little bigger and seats the castle inside it instead of at its raw
  /// edge. Used by PathComponent (backdrop) and KingdomWarsGame (world/
  /// camera bounds), not by any gameplay math (spawn points, targeting,
  /// etc. all still key off playerCastleX/enemySpawnEdgeX as before).
  static const double battlefieldMarginX = 3.2;
  static const double battlefieldStartX = playerCastleX - battlefieldMarginX;

  /// Where marching player units stop and hold ground, waiting for enemies
  /// to come into range instead of advancing all the way across the lane.
  /// 35% of the way down the lane leaves room for enemies to be intercepted
  /// well before they reach the castle.
  static const double defensiveLineX = laneLength * 0.35;

  // Multiple horizontal "tracks" so units spawned at the same time spread
  // out vertically instead of overlapping.
  static const List<double> tracks = [-1.5, -0.75, 0.0, 0.75, 1.5];

  static double trackForIndex(int spawnIndex) =>
      tracks[spawnIndex % tracks.length];

  /// Spawn position for a new player archer. Archers are a stationary
  /// defensive squad — they hold position right next to the castle and
  /// never march out, so this is their permanent position, not just a
  /// starting point. Extra archers beyond one per track stack a little
  /// further back (small x offset) so up to maxArcherSquad don't render on
  /// top of each other, while still staying tight against the castle.
  ///
  /// The castle sprite renders at 140px square (see CastleComponent),
  /// i.e. ~1.46 world units on either side of playerCastleX at
  /// pixelsPerUnit=48 — so the squad's base offset has to clear that half
  /// width (plus a small gap) or archers spawn visually on top of the
  /// castle art instead of beside it.
  static const double _castleClearanceX = 1.7;

  /// X where enemies stop at the castle wall and start hitting it. Same
  /// spot your castle-side units stand, so enemies that break through
  /// end up fighting them right at the castle.
  static const double castleContactX = _castleClearanceX;
  static (double x, double y) playerSpawnPoint(int spawnIndex) {
    final column = spawnIndex ~/ tracks.length;
    final x = playerCastleX + _castleClearanceX + column * 0.35;
    return (x, trackForIndex(spawnIndex));
  }

  /// Spawn position for a new enemy (marches from the lane's far edge
  /// toward the player castle).
  static (double x, double y) enemySpawnPoint(int spawnIndex) =>
      (enemySpawnEdgeX - 0.5, trackForIndex(spawnIndex));

  /// Direction a player unit moves in while still heading to the defensive
  /// line (+1 = toward the far edge / oncoming enemies).
  static const double playerDirection = 1.0;

  /// Direction an enemy moves in (-1 = toward the player castle).
  static const double enemyDirection = -1.0;

  /// True once a marching player unit has reached the defensive line and
  /// should stop advancing (whether or not it currently has a target).
  static bool unitReachedDefensiveLine(double x) => x >= defensiveLineX;

  static bool enemyReachedPlayerCastle(double x) => x <= playerCastleX;

  /// Grid-slot world position for tower placement, laid out in a band above
  /// the lane using GameBalance's column/row counts.
  static (double x, double y) towerSlotPosition(int col, int row) {
    const double colSpacing = laneLength / 6; // matches GameBalance.towerGridColumns
    const double rowSpacing = 1.0;
    const double bandStartY = 2.5; // keep clear of the unit tracks above
    final x = colSpacing * (col + 0.5);
    final y = bandStartY + row * rowSpacing;
    return (x, y);
  }
}
