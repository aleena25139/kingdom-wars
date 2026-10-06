// Army Management screen: shows all 4 player unit types via UnitCard.
// Archer starts unlocked; Knight/Mage/Dragon are permanently unlocked here
// with a one-time coins(+diamonds) spend, then permanently upgraded through
// 5 levels with coins — same pattern as the Castle screen. Once unlocked, a
// type auto-spawns and becomes deployable (for its own separate deploy cost)
// in every future battle. Deploy buttons themselves live on the battle
// screen's troop bar, not here.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/unit_data.dart';
import '../game_logic/state_provider.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';
import '../widgets/knight_slot_card.dart';
import '../widgets/top_hud_bar.dart';
import '../widgets/unit_card.dart';
import 'formation_screen.dart';

class ArmyScreen extends StatelessWidget {
  const ArmyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final progress = provider.progress;

    // Non-Knight types (Archer/Mage/Dragon) keep the original "unlock the
    // type once, upgrade the type" model, each rendered with UnitCard.
    // Knight instead gets its own section of UnitData.knightMaxSlots
    // individually-purchased, individually-upgraded slots — see
    // knight_slot_card.dart.
    final otherTypes = UnitType.values.where((t) => t != UnitType.knight).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡 ARMY'),
        actions: [
          TextButton.icon(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FormationScreen()));
            },
            icon: const Icon(Icons.grid_view, color: AppColors.royalGold, size: 18),
            label: const Text('FORMATION', style: TextStyle(color: AppColors.royalGold)),
          ),
        ],
      ),
      body: Column(
        children: [
          const TopHudBar(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Unlock and upgrade units here — the effect is permanent. Your army is permanent: every unit you own stands in formation next to the castle from the start of each battle and never leaves its post. Use FORMATION (top right) to choose exactly where each unit stands. If a soldier falls, you can pay its deploy cost on the battle screen to send a replacement.',
              style: TextStyle(color: AppColors.cyan, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KnightSquadSection(provider: provider),
                const SizedBox(height: 20),
                ...otherTypes.map((type) {
                  final unitDef = UnitData.defFor(type);
                  final locked = !progress.unlockedUnitTypes.contains(type);
                  final level = progress.unitLevels[type] ?? 1;
                  final canAffordUnlock =
                      progress.coins >= unitDef.unlockCost && progress.diamonds >= unitDef.unlockDiamondCost;
                  final nextUpgradeCost = level < unitDef.maxLevel ? unitDef.statAt(level + 1).upgradeCost : 0;
                  final canAffordUpgrade = level < unitDef.maxLevel && progress.coins >= nextUpgradeCost;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: UnitCard(
                      unitDef: unitDef,
                      locked: locked,
                      level: level,
                      canAffordUnlock: canAffordUnlock,
                      canAffordUpgrade: canAffordUpgrade,
                      onUnlock: () {
                        final ok = provider.purchaseUnit(type);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not enough coins/diamonds!')),
                          );
                        }
                      },
                      onUpgrade: () {
                        final ok = provider.upgradeUnit(type);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not enough coins!')),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnightSquadSection extends StatelessWidget {
  final StateProvider provider;
  const _KnightSquadSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final progress = provider.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield, color: AppColors.royalGold, size: 18),
            const SizedBox(width: 6),
            Text(
              'KNIGHT SQUAD (${progress.unlockedKnightCount}/${UnitData.knightMaxSlots})',
              style: const TextStyle(
                color: AppColors.royalGold,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            'Buy each Knight one at a time — every Knight you own fights on the '
            'field at once, standing ahead of the rest of your army, and each '
            'one levels up on its own.',
            style: TextStyle(color: AppColors.cyan, fontSize: 11),
          ),
        ),
        ...List.generate(UnitData.knightMaxSlots, (slotIndex) {
          final level = progress.knightSlotLevels[slotIndex];
          final unlockCost = UnitData.knightSlotUnlockCosts[slotIndex];
          final blockedByEarlierSlot =
              slotIndex > 0 && progress.knightSlotLevels[slotIndex - 1] == 0;
          final knightDef = UnitData.defFor(UnitType.knight);
          final nextUpgradeCost =
              level > 0 && level < knightDef.maxLevel ? knightDef.statAt(level + 1).upgradeCost : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KnightSlotCard(
              slotIndex: slotIndex,
              level: level,
              blockedByEarlierSlot: blockedByEarlierSlot,
              canAffordUnlock: progress.coins >= unlockCost,
              canAffordUpgrade: level > 0 && level < knightDef.maxLevel && progress.coins >= nextUpgradeCost,
              onUnlock: () {
                final ok = provider.purchaseKnightSlot(slotIndex);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough coins, or unlock the previous Knight first!')),
                  );
                }
              },
              onUpgrade: () {
                final ok = provider.upgradeKnightSlot(slotIndex);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough coins!')),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }
}
