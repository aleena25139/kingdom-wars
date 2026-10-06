// Full-screen version of the treasure chest system: the same free-chest
// open/countdown control as the main menu's floating widget, plus a
// breakdown of what each chest tier can contain.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../models/treasure_chest.dart';
import '../widgets/top_hud_bar.dart';
import '../widgets/treasure_chest_widget.dart';

class TreasureScreen extends StatelessWidget {
  const TreasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('🎁 TREASURE')),
      body: Column(
        children: [
          const TopHudBar(),
          const SizedBox(height: 24),
          const TreasureChestWidget(),
          const SizedBox(height: 12),
          Text(
            provider.isFreeChestReady ? 'Your free chest is ready!' : 'Next free chest in ${_format(provider.timeUntilFreeChest)}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                _TierTile(tier: ChestTier.common, color: AppColors.chestBrown, oddsLabel: '70% chance', rewardLabel: 'Coins: 100 – 500'),
                SizedBox(height: 12),
                _TierTile(tier: ChestTier.rare, color: AppColors.diamondBlue, oddsLabel: '25% chance', rewardLabel: 'Coins: 500 – 2000 • Diamonds: 20 – 100'),
                SizedBox(height: 12),
                _TierTile(tier: ChestTier.legendary, color: AppColors.royalGold, oddsLabel: '5% chance', rewardLabel: 'Coins: 2000 – 5000 • Diamonds: 100 – 500'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h' 'h ' '$m' 'm';
  }
}

class _TierTile extends StatelessWidget {
  final ChestTier tier;
  final Color color;
  final String oddsLabel;
  final String rewardLabel;

  const _TierTile({required this.tier, required this.color, required this.oddsLabel, required this.rewardLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.name.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text(oddsLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                Text(rewardLabel, style: const TextStyle(color: AppColors.cyan, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
