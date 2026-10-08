// One row in the Army screen's Knight squad section — represents a single
// purchasable Knight slot (there are UnitData.knightMaxSlots of these, e.g.
// "Knight #1".."Knight #5"). Deliberately separate from UnitCard: Knight
// isn't "unlock once, upgrade the type" like Archer/Mage/Dragon, it's "buy
// individual Knights, upgrade each one separately" — see
// PlayerProgress.knightSlotLevels / ArmyManager's per-slot spawn logic.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/unit_data.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';
import 'sprite_thumb.dart';

class KnightSlotCard extends StatelessWidget {
  final int slotIndex; // 0-based
  final int level; // 0 = not purchased yet
  final bool canAffordUnlock;
  final bool canAffordUpgrade;

  /// Slot index of the next slot the player still needs to buy before this
  /// one becomes purchasable (slots unlock left-to-right). Null once this
  /// slot itself is purchasable/purchased.
  final bool blockedByEarlierSlot;

  final VoidCallback? onUnlock;
  final VoidCallback? onUpgrade;

  const KnightSlotCard({
    super.key,
    required this.slotIndex,
    required this.level,
    required this.canAffordUnlock,
    required this.canAffordUpgrade,
    required this.blockedByEarlierSlot,
    this.onUnlock,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final knightDef = UnitData.defFor(UnitType.knight);
    final locked = level <= 0;
    final maxLevel = knightDef.maxLevel;
    final isMaxLevel = !locked && level >= maxLevel;
    final stat = knightDef.statAt(locked ? 1 : level);
    final nextStat = !locked && !isMaxLevel ? knightDef.statAt(level + 1) : null;
    final unlockCost = UnitData.knightSlotUnlockCosts[slotIndex];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: locked ? AppColors.royalGold.withValues(alpha: 0.2) : AppColors.royalGold.withValues(alpha: 0.45),
        ),
      ),
      child: Opacity(
        opacity: blockedByEarlierSlot ? 0.45 : (locked ? 0.8 : 1.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UnitAvatar(
              spriteName: knightDef.spriteName,
              radius: 26,
              locked: locked,
              accent: AppColors.emeraldGood,
              fallbackIcon: Icons.shield,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Knight #${slotIndex + 1}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                      ),
                      if (!locked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.royalGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lv $level/$maxLevel',
                            style: const TextStyle(
                                color: AppColors.royalGold, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        nextStat != null ? 'HP ${stat.hp} → ${nextStat.hp}' : 'HP ${stat.hp}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                      ),
                      Text(
                        nextStat != null ? 'DMG ${stat.damage} → ${nextStat.damage}' : 'DMG ${stat.damage}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                      ),
                    ],
                  ),
                  if (locked && blockedByEarlierSlot)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Unlock Knight #$slotIndex first',
                        style: const TextStyle(color: AppColors.cyan, fontSize: 10),
                      ),
                    )
                  else if (locked)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'Stands at the front line',
                        style: TextStyle(color: AppColors.cyan, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _ActionButton(
              locked: locked,
              disabled: locked && blockedByEarlierSlot,
              isMaxLevel: isMaxLevel,
              unlockCost: unlockCost,
              upgradeCost: nextStat?.upgradeCost ?? 0,
              canAffordUnlock: canAffordUnlock,
              canAffordUpgrade: canAffordUpgrade,
              onUnlock: onUnlock,
              onUpgrade: onUpgrade,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool locked;
  final bool disabled;
  final bool isMaxLevel;
  final int unlockCost;
  final int upgradeCost;
  final bool canAffordUnlock;
  final bool canAffordUpgrade;
  final VoidCallback? onUnlock;
  final VoidCallback? onUpgrade;

  const _ActionButton({
    required this.locked,
    required this.disabled,
    required this.isMaxLevel,
    required this.unlockCost,
    required this.upgradeCost,
    required this.canAffordUnlock,
    required this.canAffordUpgrade,
    this.onUnlock,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: (!disabled && canAffordUnlock)
                  ? () {
                      SoundService.instance.playButtonTap();
                      onUnlock?.call();
                    }
                  : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('UNLOCK', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(height: 4),
            Text('$unlockCost 🪙', style: const TextStyle(color: AppColors.royalGold, fontSize: 10)),
          ],
        ),
      );
    }
    if (isMaxLevel) {
      return const SizedBox(
        width: 88,
        child: Center(
          child: Text('MAX', style: TextStyle(color: AppColors.emeraldGood, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: canAffordUpgrade
                ? () {
                    SoundService.instance.playButtonTap();
                    onUpgrade?.call();
                  }
                : null,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('UPGRADE', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 4),
          Text('$upgradeCost 🪙', style: const TextStyle(color: AppColors.royalGold, fontSize: 10)),
        ],
      ),
    );
  }
}
