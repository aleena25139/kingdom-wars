// The floating golden-chest button seen bottom-right on the main menu.
// Shows a live countdown when the free chest isn't ready yet, or "Open" with
// a gentle pulse/glow when it is. Tapping while ready rolls rewards via
// StateProvider.openFreeChest() and shows them in an animated dialog.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../models/treasure_chest.dart';
import '../services/sound_service.dart';

class TreasureChestWidget extends StatefulWidget {
  const TreasureChestWidget({super.key});

  @override
  State<TreasureChestWidget> createState() => _TreasureChestWidgetState();
}

class _TreasureChestWidgetState extends State<TreasureChestWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  void _onTap(StateProvider provider) {
    if (!provider.isFreeChestReady) return;
    SoundService.instance.playButtonTap();
    final rewards = provider.openFreeChest();
    SoundService.instance.playVfx();
    showDialog(
      context: context,
      builder: (_) => _ChestRewardDialog(rewards: rewards),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StateProvider>(
      builder: (context, provider, _) {
        final ready = provider.isFreeChestReady;
        return GestureDetector(
          onTap: () => _onTap(provider),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glow = ready ? 8 + _pulseController.value * 10 : 0.0;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.chestBrown.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.royalGold, width: 2),
                  boxShadow: ready
                      ? [BoxShadow(color: AppColors.royalGold.withValues(alpha: 0.6), blurRadius: glow, spreadRadius: 1)]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: AppColors.royalGold, size: 34),
                    const SizedBox(height: 4),
                    Text(
                      ready ? 'Open' : _formatDuration(provider.timeUntilFreeChest),
                      style: const TextStyle(
                        color: AppColors.textGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ChestRewardDialog extends StatelessWidget {
  final ChestRewards rewards;
  const _ChestRewardDialog({required this.rewards});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.deepPurple,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.royalGold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: AppColors.royalGold, size: 48),
            const SizedBox(height: 12),
            Text(
              'Chest Opened!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _RewardRow(icon: Icons.monetization_on, color: AppColors.royalGold, label: '+${rewards.coins} Coins'),
            const SizedBox(height: 8),
            _RewardRow(icon: Icons.diamond, color: AppColors.diamondBlue, label: '+${rewards.diamonds} Diamonds'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                SoundService.instance.playButtonTap();
                Navigator.of(context).pop();
              },
              child: const Text('NICE!'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _RewardRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      ],
    );
  }
}
