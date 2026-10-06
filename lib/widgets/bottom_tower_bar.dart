// Bottom bar shown during battle with one button per tower type and its
// build cost. Tapping a button "arms" that tower type for placement —
// battle_screen.dart listens via onSelect and places the tower on the next
// grid-cell tap. Buttons dim when the player can't afford that tower.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/tower_data.dart';
import '../game_logic/state_provider.dart';
import '../models/tower.dart';
import '../services/sound_service.dart';

class BottomTowerBar extends StatelessWidget {
  final TowerType? selectedType;
  final ValueChanged<TowerType> onSelect;

  const BottomTowerBar({super.key, required this.selectedType, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;
    final coins = progress.coins;

    // Only show towers the player's current castle level has actually
    // unlocked — a locked tower doesn't appear dimmed, it simply isn't in
    // the bar yet, so the row only ever holds buttons the player can use
    // right now. It grows on its own as the castle levels up.
    final unlockedTypes = TowerType.values
        .where((type) => progress.castleLevel >= TowerData.defFor(type).unlockCastleLevel)
        .toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          // Solid (not translucent) — see TroopBar for why: an opaque panel
          // here keeps the battlefield's ground and unit shadows crisp right
          // up to its edge instead of a transparent tint muddying them.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.deepPurple, AppColors.darkPurple],
          ),
          border: Border(top: BorderSide(color: AppColors.royalGold, width: 2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: unlockedTypes.map((type) {
            final def = TowerData.defFor(type);
            final affordable = coins >= def.buildCost;
            final isSelected = selectedType == type;
            return GestureDetector(
              onTap: affordable
                  ? () {
                      SoundService.instance.playButtonTap();
                      onSelect(type);
                    }
                  : null,
              child: Opacity(
                opacity: affordable ? 1.0 : 0.4,
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.royalGold.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.royalGold : AppColors.cyan.withValues(alpha: 0.4),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(type), color: AppColors.textGold, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        '${def.buildCost}',
                        style: const TextStyle(color: AppColors.royalGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _iconFor(TowerType type) {
    switch (type) {
      case TowerType.cannon:
        return Icons.circle;
      case TowerType.archer:
        return Icons.gps_fixed;
      case TowerType.mage:
        return Icons.auto_fix_high;
      case TowerType.flamethrower:
        return Icons.local_fire_department;
      case TowerType.sniper:
        return Icons.center_focus_strong;
      case TowerType.tesla:
        return Icons.bolt;
    }
  }
}
