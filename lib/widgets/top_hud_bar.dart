// Reusable currency HUD row shown on the main menu and other meta screens
// (castle upgrade, army, campaign). Purely presentational — reads
// StateProvider.progress and renders four chips.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';

class TopHudBar extends StatelessWidget {
  const TopHudBar({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HudChip(icon: Icons.monetization_on, color: AppColors.royalGold, value: '${progress.coins}'),
          HudChip(icon: Icons.diamond, color: AppColors.diamondBlue, value: '${progress.diamonds}'),
          HudChip(icon: Icons.star, color: AppColors.lightGold, value: 'Lvl ${progress.playerLevel}'),
          HudChip(icon: Icons.castle, color: AppColors.emeraldGood, value: 'Castle ${progress.castleLevel}'),
        ],
      ),
    );
  }
}

class HudChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  const HudChip({super.key, required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
