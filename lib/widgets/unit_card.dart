// Reusable stat card for a single army unit type, used by army_screen.dart
// to list all 4 player units. Three states:
//  - Locked: shows a lock icon and an "UNLOCK" button (coins + diamonds).
//  - Unlocked, not max level: shows current-level stats and an "UPGRADE"
//    button (coins) with a preview of the next level's stats.
//  - Unlocked, max level: shows current stats with a "MAX LEVEL" badge.
// Purely presentational — army_screen.dart supplies level/locked state and
// wires the callbacks to StateProvider.purchaseUnit/upgradeUnit.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/unit_data.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';
import 'sprite_thumb.dart';

class UnitCard extends StatelessWidget {
  final UnitDef unitDef;
  final bool locked;
  final int level; // ignored when locked
  final VoidCallback? onUnlock;
  final VoidCallback? onUpgrade;
  final bool canAffordUnlock;
  final bool canAffordUpgrade;

  const UnitCard({
    super.key,
    required this.unitDef,
    required this.locked,
    this.level = 1,
    this.onUnlock,
    this.onUpgrade,
    this.canAffordUnlock = false,
    this.canAffordUpgrade = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxLevel = unitDef.maxLevel;
    final isMaxLevel = !locked && level >= maxLevel;
    final stat = unitDef.statAt(locked ? 1 : level);
    final nextStat = !locked && !isMaxLevel ? unitDef.statAt(level + 1) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? AppColors.royalGold.withValues(alpha: 0.25) : AppColors.royalGold.withValues(alpha: 0.5),
        ),
      ),
      child: Opacity(
        opacity: locked ? 0.75 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UnitAvatar(
              spriteName: unitDef.spriteName,
              radius: 30,
              locked: locked,
              accent: AppColors.emeraldGood,
              fallbackIcon: _iconFor(unitDef),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(unitDef.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                      if (!locked) ...[
                        const SizedBox(width: 8),
                        _LevelBadge(level: level, maxLevel: maxLevel),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      _StatPill(label: 'HP', value: '${stat.hp}', nextValue: nextStat != null ? '${nextStat.hp}' : null),
                      _StatPill(
                        label: 'DMG',
                        value: '${stat.damage}',
                        nextValue: nextStat != null ? '${nextStat.damage}' : null,
                      ),
                      _StatPill(label: 'SPD', value: unitDef.speed.toStringAsFixed(1)),
                    ],
                  ),
                  if (unitDef.isRanged || unitDef.healsNearby || unitDef.isFlying || unitDef.isAoe || unitDef.usesMindControl)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (unitDef.isRanged) 'Ranged',
                          if (unitDef.isAoe) 'AoE',
                          if (unitDef.healsNearby) 'Heals allies',
                          if (unitDef.usesMindControl) 'Mind control',
                          if (unitDef.isFlying) 'Flying',
                        ].join(' • '),
                        style: const TextStyle(color: AppColors.cyan, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              locked: locked,
              isMaxLevel: isMaxLevel,
              unlockCost: unitDef.unlockCost,
              unlockDiamondCost: unitDef.unlockDiamondCost,
              upgradeCost: nextStat == null ? 0 : (unitDef.statAt(level + 1)).upgradeCost,
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

  IconData _iconFor(UnitDef def) {
    switch (def.type) {
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
}

class _ActionButton extends StatelessWidget {
  final bool locked;
  final bool isMaxLevel;
  final int unlockCost;
  final int unlockDiamondCost;
  final int upgradeCost;
  final bool canAffordUnlock;
  final bool canAffordUpgrade;
  final VoidCallback? onUnlock;
  final VoidCallback? onUpgrade;

  const _ActionButton({
    required this.locked,
    required this.isMaxLevel,
    required this.unlockCost,
    required this.unlockDiamondCost,
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
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: canAffordUnlock
                  ? () {
                      SoundService.instance.playButtonTap();
                      onUnlock?.call();
                    }
                  : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('UNLOCK', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              unlockDiamondCost > 0 ? '$unlockCost 🪙 + $unlockDiamondCost 💎' : '$unlockCost 🪙',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(color: AppColors.royalGold, fontSize: 10),
            ),
            ),
          ],
        ),
      );
    }
    if (isMaxLevel) {
      return const SizedBox(
        width: 96,
        child: Center(
          child: Text('MAX LEVEL', style: TextStyle(color: AppColors.emeraldGood, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return SizedBox(
      width: 96,
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
              child: Text('UPGRADE', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 4),
          Text('$upgradeCost 🪙', style: const TextStyle(color: AppColors.royalGold, fontSize: 10)),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final int maxLevel;
  const _LevelBadge({required this.level, required this.maxLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.royalGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Lv $level/$maxLevel',
        style: const TextStyle(color: AppColors.royalGold, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final String? nextValue;
  const _StatPill({required this.label, required this.value, this.nextValue});

  @override
  Widget build(BuildContext context) {
    return Text(
      nextValue != null ? '$label $value → $nextValue' : '$label $value',
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    );
  }
}
