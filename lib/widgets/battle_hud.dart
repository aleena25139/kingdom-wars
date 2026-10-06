// The battle-specific top HUD (spec section "BATTLE HUD"): your castle's
// red HP bar (this is a pure defense layout — there's no enemy castle),
// "Wave X/Y", coins earned this battle, and the 1x/2x/3x speed toggle.
// Pausing is handled solely by the hamburger menu (BattleScreen) — no
// separate pause button here. Rebuilds every frame via the Consumer so the
// bar/wave counter stay live.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../services/sound_service.dart';

class BattleHud extends StatefulWidget {
  const BattleHud({super.key});

  @override
  State<BattleHud> createState() => _BattleHudState();
}

class _BattleHudState extends State<BattleHud> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // StateProvider.tickBattle() only notifies listeners when the battle ENDS
    // (notifying 60x/second would rebuild every screen), so nothing told this
    // HUD to repaint while fighting: the red castle bar, wave counter and
    // coins stayed frozen at their starting values. Repaint ~10x/second.
    _refresh = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StateProvider>(
      builder: (context, provider, _) {
        final battle = provider.gameEngine.activeBattle;
        if (battle == null) return const SizedBox.shrink();

        final waveLabel = battle.totalWaves < 0
            ? 'Wave ${battle.currentWaveNumber}'
            : 'Wave ${battle.currentWaveNumber}/${battle.totalWaves}';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HpBar(
                        label: '❤️ Your Castle',
                        percent: battle.playerCastle.hpPercent,
                        color: AppColors.crimsonEvil,
                      ),
                    ),
                    // Reserve space so the bar doesn't run under the
                    // hamburger icon stacked on top of the HUD in
                    // battle_screen.dart.
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _MpBar(mp: battle.mp, maxMp: battle.maxMp, low: battle.mpLow),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('⚔ $waveLabel', style: const TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold)),
                        if (battle.isEndless) ...[
                          const SizedBox(width: 10),
                          Text('🏆 Score ${battle.score}',
                              style: const TextStyle(color: AppColors.lightGold, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            SoundService.instance.playButtonTap();
                            provider.cycleSpeed();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.cyan),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${provider.gameEngine.speedMultiplier.toInt()}x',
                              style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('💰 ${provider.progress.coins}', style: const TextStyle(color: AppColors.royalGold, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Text('💎 ${provider.progress.diamonds}', style: const TextStyle(color: AppColors.diamondBlue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HpBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final bool alignEnd;

  const _HpBar({
    required this.label,
    required this.percent,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.black45,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Blue MP (mana) bar under the castle HP bar. This is the castle's whole MP
/// pool: it starts full, every unit's own MP bar draws from it while charging,
/// and the battle is lost if it reaches zero — so it turns red when low.
class _MpBar extends StatelessWidget {
  final double mp;
  final double maxMp;
  final bool low;

  const _MpBar({required this.mp, required this.maxMp, required this.low});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF42A5F5);
    final color = low ? AppColors.crimsonEvil : blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          low ? '🔵 MP ${mp.ceil()}/${maxMp.round()}  —  LOW! Game over at 0' : '🔵 MP ${mp.ceil()}/${maxMp.round()}',
          style: TextStyle(color: low ? color : AppColors.textPrimary, fontSize: 12, fontWeight: low ? FontWeight.bold : FontWeight.normal),
        ),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: low ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 8)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: maxMp <= 0 ? 0 : (mp / maxMp).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.black45,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}
