// The player's army is a PERMANENT FORMATION, like soldiers standing in
// ranks: when a battle starts every unit the player owns is placed, once, in
// a grid cell. Nobody marches out, nobody keeps streaming out of the castle
// on a timer — units hold their cell and attack whatever comes into range.
//
// THE PLAYER DECIDES WHO STANDS WHERE. The field is a grid of
// [gridCols] x [gridRows] cells (col 0 = front rank, nearest the enemy;
// row 0..4 = top to bottom). PlayerProgress.formation remembers the cell the
// player chose for every soldier ("<type>#<n>" -> col*10+row). Soldiers the
// player has not placed yet get a sensible default cell:
//   1) Panda Warriors + Elf Princes   2) Knights   3) Archers
//   4) Mages + Dragon + Magician + Phoenix
//
// How many soldiers stand:
//   * Knight  -> one per purchased Knight slot (PlayerProgress.knightSlotLevels,
//               each with its own level).
//   * others  -> UnitData.squadSize, all at that type's permanent level.
// A fallen soldier is NOT replaced automatically. The player can pay the
// deploy cost on the troop bar to send a replacement into the empty slot.
import '../constants/unit_data.dart';
import '../models/castle.dart';
import '../models/unit.dart';

class FormationSlot {
  final int index;
  final String key; // stable soldier id, e.g. "knight#0", "archer#3"
  final UnitType type;
  final int level;
  final int col; // 0 = front rank
  final int row;
  final double x;
  final double y;
  const FormationSlot({
    required this.index,
    required this.key,
    required this.type,
    required this.level,
    required this.col,
    required this.row,
    required this.x,
    required this.y,
  });
}

class _Entry {
  final String key;
  final UnitType type;
  final int level;
  final int defCol;
  final int defRow;
  _Entry(this.key, this.type, this.level, this.defCol, this.defRow);
}

class ArmyManager {
  final Set<UnitType> unlockedUnitTypes;
  final Map<UnitType, int> unitLevels;
  final List<int> knightSlotLevels;

  // Formation geometry (world units; 1.0 == 48px).
  static const int gridCols = 5;
  static const int gridRows = 5;
  static const double frontRankX = 4.9; // x of the front rank (col 0)
  static const double rankSpacing = 0.75; // gap between ranks
  static const double rowSpacing = 0.8; // gap between soldiers in a rank
  static const int maxPerRank = 5;

  static double cellX(int col) => frontRankX - col * rankSpacing;
  static double cellY(int row) => (row - (gridRows - 1) / 2) * rowSpacing;
  static int cellId(int col, int row) => col * 10 + row;

  late List<FormationSlot> slots;
  int _idCounter = 0;

  ArmyManager({
    required this.unlockedUnitTypes,
    required this.unitLevels,
    required this.knightSlotLevels,
    Map<String, int> formation = const {},
  }) {
    slots = layout(
      unlockedUnitTypes: unlockedUnitTypes,
      unitLevels: unitLevels,
      knightSlotLevels: knightSlotLevels,
      formation: formation,
    );
  }

  /// Re-reads the formation (player rearranged the army). Slot indices are
  /// re-issued; BattleEngine.applyFormation re-links living soldiers.
  void setFormation(Map<String, int> formation) {
    slots = layout(
      unlockedUnitTypes: unlockedUnitTypes,
      unitLevels: unitLevels,
      knightSlotLevels: knightSlotLevels,
      formation: formation,
    );
  }

  // ------------------------------------------------------------------
  // Formation layout (also used by the Formation screen, so what the
  // player sees there is exactly what stands on the battlefield)
  // ------------------------------------------------------------------

  static List<FormationSlot> layout({
    required Set<UnitType> unlockedUnitTypes,
    required Map<UnitType, int> unitLevels,
    required List<int> knightSlotLevels,
    required Map<String, int> formation,
  }) {
    // 1) every soldier that stands, in default front-to-back order, each with
    //    its default cell.
    List<(UnitType, int, int)> entriesFor(UnitType type) {
      // (type, level, index within the type)
      if (type == UnitType.knight) {
        return [
          for (var i = 0; i < knightSlotLevels.length; i++)
            if (knightSlotLevels[i] > 0) (UnitType.knight, knightSlotLevels[i], i),
        ];
      }
      if (!unlockedUnitTypes.contains(type)) return const [];
      final level = unitLevels[type] ?? 1;
      return [for (var i = 0; i < UnitData.squadSizeOf(type); i++) (type, level, i)];
    }

    final entries = <_Entry>[];
    var rankIndex = 0;
    for (final rankGroup in const [
      [UnitType.pandaWarrior, UnitType.elfPrince],
      [UnitType.knight],
      [UnitType.archer],
      [UnitType.mage, UnitType.dragon, UnitType.magician, UnitType.phoenix],
    ]) {
      final group = <(UnitType, int, int)>[
        for (final t in rankGroup) ...entriesFor(t),
      ];
      for (var start = 0; start < group.length; start += maxPerRank) {
        final end = start + maxPerRank > group.length ? group.length : start + maxPerRank;
        final chunk = group.sublist(start, end);
        final firstRow = (gridRows - chunk.length) ~/ 2;
        final col = rankIndex < gridCols ? rankIndex : gridCols - 1;
        for (var i = 0; i < chunk.length; i++) {
          final (type, level, idx) = chunk[i];
          entries.add(_Entry('${type.name}#$idx', type, level, col, firstRow + i));
        }
        rankIndex++;
      }
    }

    // 2) the player's chosen cells first...
    final taken = <int>{};
    final chosen = <String, int>{};
    for (final e in entries) {
      final v = formation[e.key];
      if (v == null) continue;
      final c = v ~/ 10;
      final r = v % 10;
      if (c < 0 || c >= gridCols || r < 0 || r >= gridRows) continue;
      if (taken.contains(v)) continue;
      taken.add(v);
      chosen[e.key] = v;
    }
    // ...then everyone else gets their default cell, or the nearest free one.
    for (final e in entries) {
      if (chosen.containsKey(e.key)) continue;
      var best = -1;
      var bestDist = 1 << 30;
      for (var c = 0; c < gridCols; c++) {
        for (var r = 0; r < gridRows; r++) {
          final id = cellId(c, r);
          if (taken.contains(id)) continue;
          final dist = (c - e.defCol).abs() * 10 + (r - e.defRow).abs();
          if (dist < bestDist) {
            bestDist = dist;
            best = id;
          }
        }
      }
      taken.add(best);
      chosen[e.key] = best;
    }

    return [
      for (var i = 0; i < entries.length; i++)
        FormationSlot(
          index: i,
          key: entries[i].key,
          type: entries[i].type,
          level: entries[i].level,
          col: chosen[entries[i].key]! ~/ 10,
          row: chosen[entries[i].key]! % 10,
          x: cellX(chosen[entries[i].key]! ~/ 10),
          y: cellY(chosen[entries[i].key]! % 10),
        ),
    ];
  }

  // ------------------------------------------------------------------
  // Spawning
  // ------------------------------------------------------------------

  /// The whole army, standing in formation. Called once when the battle
  /// starts.
  List<Unit> initialUnits(Castle playerCastle) => [for (final s in slots) _spawn(s)];

  int squadSizeOf(UnitType type) => slots.where((s) => s.type == type).length;

  int aliveOf(UnitType type, List<Unit> aliveUnits) =>
      aliveUnits.where((u) => u.alive && u.type == type).length;

  FormationSlot? _freeSlotFor(UnitType type, List<Unit> aliveUnits) {
    final taken = {for (final u in aliveUnits) if (u.alive) u.formationKey};
    for (final s in slots) {
      if (s.type == type && !taken.contains(s.key)) return s;
    }
    return null;
  }

  bool canDeploy(UnitType type, List<Unit> aliveUnits) => _freeSlotFor(type, aliveUnits) != null;

  /// Player paid to replace a fallen soldier: puts a new one into the first
  /// empty slot of that type. Returns null if that type has no empty slot
  /// (squad already at full strength / type not owned) — nothing is spent.
  Unit? deployReinforcement(UnitType type, List<Unit> aliveUnits) {
    final slot = _freeSlotFor(type, aliveUnits);
    return slot == null ? null : _spawn(slot);
  }

  Unit _spawn(FormationSlot slot) {
    final def = UnitData.defFor(slot.type);
    final stat = def.statAt(slot.level);
    return Unit(
      id: 'unit_${slot.type.name}_${_idCounter++}_${DateTime.now().microsecondsSinceEpoch}',
      type: slot.type,
      spriteName: def.spriteName,
      maxHp: stat.hp,
      damage: stat.damage,
      speed: 0, // formation soldiers never march
      isRanged: def.isRanged,
      range: def.range,
      isFlying: def.isFlying,
      isAoe: def.isAoe,
      healsNearby: def.healsNearby,
      usesLightning: def.usesLightning,
      usesKungFu: def.usesKungFu,
      usesMindControl: def.usesMindControl,
      advanceToX: def.advanceToX,
      advanceSpeed: def.advanceSpeed,
      x: slot.x,
      y: slot.y,
    )
      ..slot = slot.index
      ..level = slot.level
      ..formationKey = slot.key;
  }
}
