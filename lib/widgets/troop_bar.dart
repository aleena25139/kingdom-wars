// Bottom bar shown during battle with one button per army unit type, its own
// MP bar and (when a soldier has fallen) its coin deploy cost. Tapping a button immediately spends coins and spawns that
// unit from the player's castle via StateProvider.deployReinforcement — no
// placement step needed (units always enter at the player spawn point and
// march on their own, unlike towers). Buttons dim when the player can't
// afford that unit.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/game_balance.dart';
import '../constants/unit_data.dart';
import '../game_logic/state_provider.dart';
import '../models/unit.dart';
import '../services/sound_service.dart';

class TroopBar extends StatefulWidget {
  const TroopBar({super.key});

  @override
  State<TroopBar> createState() => _TroopBarState();
}

class _TroopBarState extends State<TroopBar> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // The battle ticks without notifying listeners, so repaint ~10x/second
    // to keep the MP-ready glow and boost countdown live.
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
    final provider = context.watch<StateProvider>();
    final coins = provider.progress.coins;
    final battle = provider.gameEngine.activeBattle;
    // Each unit type shows up here the moment it's unlocked on the Army
    // screen — Knight uses anyKnightUnlocked (5-slot system) instead of the
    // shared unlockedUnitTypes set the other 3 types use.
    final unlockedTypes = UnitType.values.where((t) {
      if (t == UnitType.knight) return provider.progress.anyKnightUnlocked;
      return provider.progress.unlockedUnitTypes.contains(t);
    }).toList();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          // Solid (not translucent) so this strip reads as its own opaque
          // wooden panel rather than a faint tint over the battlefield —
          // the ground and every unit's shadow above it now stay clearly
          // visible right up to the panel's edge instead of fading into it.
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
            final def = UnitData.defFor(type);
            // Deploying replaces a fallen soldier in the formation, so it is
            // only possible while that type has an empty slot.
            final canDeploy = battle?.canDeploy(type) ?? false;
            final affordable = coins >= def.deployCost && canDeploy;
            final alive = battle?.aliveOf(type) ?? 0;
            // Every unit type has its OWN MP bar (Archer = 50 MP ...):
            //   idle      -> tap to start charging it (MP moves out of the castle pool)
            //   charging  -> fills slowly
            //   full      -> tap = BOOST (fights faster for a few seconds)
            // A fallen soldier can still be replaced for coins (tap while the
            // type is below full strength and not boost-ready).
            final unitMax = battle?.unitMpMax(type) ?? 1.0;
            final unitMp = battle?.unitMpOf(type) ?? 0.0;
            final boostReady = (battle?.unitMpFull(type) ?? false) && alive > 0;
            final charging = battle?.isCharging(type) ?? false;
            final boosted = battle?.isBoosted(type) ?? false;
            final boostLeft = battle?.boostLeftFor(type) ?? 0;
            final canCharge = !boostReady && !charging && !boosted && alive > 0 && (battle?.mp ?? 0) > 0;
            final deployFirst = affordable && !boostReady;
            const mpBlue = Color(0xFF42A5F5);
            return GestureDetector(
              onTap: boostReady
                  ? () {
                      SoundService.instance.playButtonTap();
                      provider.activateBoost(type);
                    }
                  : (deployFirst
                      ? () {
                          SoundService.instance.playButtonTap();
                          provider.deployReinforcement(type);
                        }
                      : (canCharge
                          ? () {
                              SoundService.instance.playButtonTap();
                              provider.startCharge(type);
                            }
                          : null)),
              child: Opacity(
                opacity: (affordable || boostReady || boosted || charging || canCharge) ? 1.0 : 0.4,
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: boosted ? mpBlue.withOpacity(0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (boostReady || boosted) ? mpBlue : AppColors.emeraldGood.withOpacity(0.4),
                      width: (boostReady || boosted) ? 2 : 1,
                    ),
                    boxShadow: boostReady ? [BoxShadow(color: mpBlue.withOpacity(0.7), blurRadius: 10)] : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(type), color: AppColors.textGold, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        def.displayName,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        boosted
                            ? '⚡${boostLeft.toStringAsFixed(1)}s'
                            : (boostReady
                                ? '⚡ BOOST'
                                : (deployFirst ? '${def.deployCost}🪙' : '${unitMp.floor()}/${unitMax.round()} MP')),
                        style: TextStyle(
                          color: (boostReady || boosted || charging) ? mpBlue : AppColors.royalGold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // This unit's own MP bar.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: boosted ? (boostLeft / GameBalance.boostSeconds).clamp(0.0, 1.0) : (unitMp / unitMax).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.black45,
                            valueColor: AlwaysStoppedAnimation(boosted ? AppColors.royalGold : mpBlue),
                          ),
                        ),
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
}
