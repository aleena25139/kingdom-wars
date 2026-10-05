// FORMATION: the player decides where every soldier stands.
//
// The battlefield is shown as a 5 x 5 grid: the castle on the left, the
// enemy coming from the right. The column nearest the enemy (rightmost) is the
// FRONT rank. Drag a unit onto any cell — or tap a unit and then tap a cell —
// to move it; dropping it on another unit swaps the two. Tap a unit to see its
// stats and to upgrade it (more power). Everything is saved, and the same
// screen can be opened from the pause menu mid-battle (soldiers then walk to
// their new cells).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/unit_data.dart';
import '../game_logic/army_manager.dart';
import '../game_logic/state_provider.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';
import '../widgets/sprite_thumb.dart';

class FormationScreen extends StatefulWidget {
  const FormationScreen({super.key});

  @override
  State<FormationScreen> createState() => _FormationScreenState();
}

class _FormationScreenState extends State<FormationScreen> {
  String? _selectedKey;

  void _move(StateProvider provider, String key, int col, int row) {
    final moved = provider.moveFormationUnit(key, col, row);
    if (moved) SoundService.instance.playButtonTap();
    setState(() => _selectedKey = key);
  }

  void _tapCell(StateProvider provider, int col, int row, FormationSlot? occupant) {
    final sel = _selectedKey;
    if (sel == null) {
      if (occupant != null) setState(() => _selectedKey = occupant.key);
      return;
    }
    if (occupant != null && occupant.key == sel) {
      setState(() => _selectedKey = null);
      return;
    }
    // Empty cell: move there. Another unit's cell: swap with it.
    _move(provider, sel, col, row);
  }

  IconData _iconFor(UnitType type) {
    switch (type) {
      case UnitType.archer:
        return Icons.gps_fixed;
      case UnitType.knight:
        return Icons.shield;
      case UnitType.mage:
        return Icons.auto_fix_high;
      case UnitType.dragon:
        return Icons.whatshot;
      case UnitType.pandaWarrior:
        return Icons.pets;
      case UnitType.elfPrince:
        return Icons.psychology;
      case UnitType.magician:
        return Icons.auto_awesome;
      case UnitType.phoenix:
        return Icons.local_fire_department;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final slots = provider.currentFormationSlots();
    final bySlotCell = <int, FormationSlot>{
      for (final s in slots) ArmyManager.cellId(s.col, s.row): s,
    };
    FormationSlot? selected;
    for (final s in slots) {
      if (s.key == _selectedKey) selected = s;
    }
    if (selected == null && _selectedKey != null) {
      // The selected soldier no longer exists (e.g. progress reset).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedKey = null);
      });
    }
    final inBattle = provider.gameEngine.hasActiveBattle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔ FORMATION'),
        actions: [
          TextButton.icon(
            onPressed: () {
              SoundService.instance.playButtonTap();
              provider.resetFormation();
              setState(() => _selectedKey = null);
            },
            icon: const Icon(Icons.auto_fix_normal, color: AppColors.royalGold, size: 18),
            label: const Text('AUTO', style: TextStyle(color: AppColors.royalGold)),
          ),
        ],
      ),
      body: slots.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have no soldiers yet. Unlock units on the Army screen first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > box.maxHeight;
                final gridArea = wide ? box.maxWidth * 0.62 : box.maxWidth;
                final gridHeightLimit = wide ? box.maxHeight - 56 : box.maxHeight * 0.55;
                final byWidth = (gridArea - 24) / ArmyManager.gridCols;
                final byHeight = gridHeightLimit / ArmyManager.gridRows;
                final cell = (byWidth < byHeight ? byWidth : byHeight).clamp(30.0, 90.0).toDouble();

                final grid = _buildGrid(provider, bySlotCell, cell);
                final panel = _buildPanel(provider, selected, inBattle);

                if (wide) {
                  return Row(
                    children: [
                      SizedBox(width: gridArea, child: Center(child: SingleChildScrollView(child: grid))),
                      Expanded(child: panel),
                    ],
                  );
                }
                return Column(
                  children: [
                    Center(child: grid),
                    Expanded(child: panel),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildGrid(StateProvider provider, Map<int, FormationSlot> bySlotCell, double cell) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cell * ArmyManager.gridCols,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🏰 CASTLE', style: TextStyle(color: AppColors.royalGold, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('FRONT ➜ ENEMY', style: TextStyle(color: AppColors.crimsonEvil, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14331F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.royalGold.withOpacity(0.6), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left = back rank (next to the castle), right = front rank.
              for (var col = ArmyManager.gridCols - 1; col >= 0; col--)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < ArmyManager.gridRows; row++)
                      _buildCell(provider, col, row, bySlotCell[ArmyManager.cellId(col, row)], cell),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(StateProvider provider, int col, int row, FormationSlot? slot, double cell) {
    final isSelected = slot != null && slot.key == _selectedKey;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _move(provider, details.data, col, row),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapCell(provider, col, row, slot),
          child: Container(
            width: cell,
            height: cell,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: hovering
                  ? AppColors.royalGold.withOpacity(0.35)
                  : (col == 0 ? const Color(0x22FF5252) : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.royalGold : Colors.white.withOpacity(0.12),
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: slot == null ? null : _buildUnitTile(slot, cell),
          ),
        );
      },
    );
  }

  Widget _buildUnitTile(FormationSlot slot, double cell) {
    final def = UnitData.defFor(slot.type);
    final art = Stack(
      alignment: Alignment.center,
      children: [
        SpriteThumb(
          spriteName: def.spriteName,
          size: cell * 0.78,
          fallbackIcon: _iconFor(slot.type),
          fallbackColor: AppColors.textGold,
        ),
        Positioned(
          bottom: 0,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${slot.level}', style: const TextStyle(color: AppColors.royalGold, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
    return Draggable<String>(
      data: slot.key,
      onDragStarted: () => setState(() => _selectedKey = slot.key),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: cell, height: cell, child: art),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: art),
      child: art,
    );
  }

  Widget _buildPanel(StateProvider provider, FormationSlot? selected, bool inBattle) {
    final progress = provider.progress;
    final children = <Widget>[];

    if (selected == null) {
      children.add(const Text(
        'Drag a unit to any square, or tap a unit and then tap the square you want. '
        'Dropping it on another unit swaps them.\n\n'
        '• Right side = FRONT (meets the enemy first): put tough fighters there — Knight, Panda, Elf Prince.\n'
        '• Left side = BACK (next to the castle): archers, mages, dragon, magician.\n\n'
        'Tap a unit to see its power and upgrade it.',
        style: TextStyle(color: AppColors.cyan, fontSize: 12, height: 1.35),
      ));
    } else {
      final def = UnitData.defFor(selected.type);
      final stat = def.statAt(selected.level);
      final isKnight = selected.type == UnitType.knight;
      final knightIndex = isKnight ? int.tryParse(selected.key.split('#').last) ?? 0 : 0;
      final canUpgrade = selected.level < def.maxLevel;
      final cost = canUpgrade ? def.statAt(selected.level + 1).upgradeCost : 0;
      final affordable = progress.coins >= cost;
      final next = canUpgrade ? def.statAt(selected.level + 1) : null;

      children.addAll([
        Row(
          children: [
            SpriteThumb(
              spriteName: def.spriteName,
              size: 54,
              fallbackIcon: _iconFor(selected.type),
              fallbackColor: AppColors.textGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKnight ? 'Knight #${knightIndex + 1}' : def.displayName,
                    style: const TextStyle(color: AppColors.royalGold, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('Level ${selected.level} / ${def.maxLevel}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _statRow('❤ HP', '${stat.hp}', next == null ? null : '${next.hp}'),
        _statRow('⚔ Damage', '${stat.damage}', next == null ? null : '${next.damage}'),
        _statRow('🎯 Reach', def.isRanged || def.usesLightning ? def.range.toStringAsFixed(1) : 'Close combat', null),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canUpgrade && affordable
                ? () {
                    SoundService.instance.playButtonTap();
                    final ok = isKnight ? provider.upgradeKnightSlot(knightIndex) : provider.upgradeUnit(selected.type);
                    if (ok) SoundService.instance.playVfx(volume: 0.6);
                  }
                : null,
            icon: const Icon(Icons.arrow_upward),
            label: Text(canUpgrade ? 'UPGRADE POWER  $cost 🪙' : 'MAX LEVEL'),
          ),
        ),
        if (canUpgrade && !affordable)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Not enough coins.', style: TextStyle(color: AppColors.crimsonEvil, fontSize: 11)),
          ),
        if (!isKnight && canUpgrade)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Upgrades the whole squad of this type.', style: TextStyle(color: AppColors.cyan, fontSize: 10)),
          ),
        if (inBattle && canUpgrade)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('Upgraded stats apply from the next battle.', style: TextStyle(color: AppColors.cyan, fontSize: 10)),
          ),
      ]);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.royalGold.withOpacity(0.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🪙 ${progress.coins}', style: const TextStyle(color: AppColors.royalGold, fontWeight: FontWeight.bold)),
                if (inBattle)
                  const Text('LIVE — units walk to new spots', style: TextStyle(color: AppColors.cyan, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, String? nextValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
          Text(value, style: const TextStyle(color: AppColors.textGold, fontSize: 12, fontWeight: FontWeight.bold)),
          if (nextValue != null)
            Text('  ➜ $nextValue', style: const TextStyle(color: AppColors.emeraldGood, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
