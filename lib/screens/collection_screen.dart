// The Collection screen: a read-only codex/gallery of everything in the
// game — army units, towers, and enemy bestiary — across three tabs. Unlike
// ArmyScreen (which spends coins/diamonds to unlock or upgrade) this screen
// never mutates PlayerProgress; it only reads it to decide what's still a
// silhouette ("???", locked) versus fully revealed. Towers have no
// persistent unlock in this game (any tower is buildable in battle once you
// can afford it), so the Towers tab is always fully revealed — it's the
// stats/flavor reference for what you've already been building. Nothing
// new is added to PlayerProgress/save_service for this: every lock check
// below is derived from state the game already tracks.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/enemy_data.dart';
import '../constants/level_data.dart';
import '../models/level.dart';
import '../constants/tower_data.dart';
import '../constants/unit_data.dart';
import '../game_logic/state_provider.dart';
import '../services/sound_service.dart';
import '../models/enemy.dart';
import '../models/player_progress.dart';
import '../models/tower.dart';
import '../models/unit.dart';
import '../widgets/collection_entry_card.dart';
import '../widgets/top_hud_bar.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📖 COLLECTION'),
          bottom: TabBar(
            onTap: (_) => SoundService.instance.playButtonTap(),
            tabs: const [
              Tab(text: 'ARMY'),
              Tab(text: 'TOWERS'),
              Tab(text: 'BESTIARY'),
            ],
          ),
        ),
        body: Column(
          children: [
            const TopHudBar(),
            const Expanded(
              child: TabBarView(
                children: [
                  _ArmyTab(),
                  _TowersTab(),
                  _BestiaryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "N / total discovered" strip shown at the top of every tab.
class _ProgressStrip extends StatelessWidget {
  final int unlocked;
  final int total;
  const _ProgressStrip({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Icon(Icons.auto_stories, color: AppColors.royalGold, size: 18),
          const SizedBox(width: 8),
          Text(
            '$unlocked / $total discovered',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ArmyTab extends StatelessWidget {
  const _ArmyTab();

  static const Map<UnitType, IconData> _icons = {
    UnitType.archer: Icons.gps_fixed,
    UnitType.knight: Icons.shield,
    UnitType.mage: Icons.auto_fix_high,
    UnitType.dragon: Icons.whatshot,
    UnitType.pandaWarrior: Icons.pets,
    UnitType.elfPrince: Icons.psychology,
    UnitType.magician: Icons.auto_awesome,
    UnitType.phoenix: Icons.local_fire_department,
  };

  static const Map<UnitType, String> _flavor = {
    UnitType.archer: 'Holds the line with a longbow — cheap, steady, always ready.',
    UnitType.knight: 'Marches out to the front line and refuses to fall back.',
    UnitType.mage: 'Channels arcane fire that scorches every foe caught in the blast.',
    UnitType.dragon: "The kingdom's last resort — death raining from the sky.",
    UnitType.pandaWarrior: 'An elite kung-fu master. Only 3 stand in the squad; holds his post and destroys anything that steps in reach with flying kicks, palm flurries and spin kicks.',
    UnitType.elfPrince: 'A royal elf who calls fire down from the sky onto his foes. His special power is MIND CONTROL: every few seconds he enchants nearby Goblins and Orcs, who then turn on their own army and fight for you for a while.',
    UnitType.magician: 'A wise magician who heals every wounded ally nearby every few seconds and strikes foes with glowing magic bolts.',
    UnitType.phoenix: 'A blazing fire bird that rains exploding fireballs from the sky. Stronger than the Dragon.',
  };

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;
    final types = UnitType.values;
    final unlockedCount = types.where((t) {
      if (t == UnitType.knight) return progress.anyKnightUnlocked;
      return progress.unlockedUnitTypes.contains(t);
    }).length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: types.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) return _ProgressStrip(unlocked: unlockedCount, total: types.length);
        final type = types[i - 1];
        final def = UnitData.defFor(type);
        final isKnight = type == UnitType.knight;
        final locked = isKnight ? !progress.anyKnightUnlocked : !progress.unlockedUnitTypes.contains(type);
        final level = isKnight
            ? (progress.knightSlotLevels.where((l) => l > 0).isEmpty
                ? 1
                : progress.knightSlotLevels.firstWhere((l) => l > 0))
            : (progress.unitLevels[type] ?? 1);
        final stat = def.statAt(level);
        final statsLine = isKnight
            ? 'Lv $level • HP ${stat.hp} • DMG ${stat.damage} • ${progress.unlockedKnightCount}/${UnitData.knightMaxSlots} squad slots'
            : 'Lv $level • HP ${stat.hp} • DMG ${stat.damage}';

        return CollectionEntryCard(
          icon: _icons[type]!,
          spriteName: def.spriteName,
          accentColor: AppColors.emeraldGood,
          name: def.displayName,
          statsLine: statsLine,
          flavorText: _flavor[type]!,
          locked: locked,
          lockedHint: 'Unlock from the Army screen',
        );
      },
    );
  }
}

class _TowersTab extends StatelessWidget {
  const _TowersTab();

  static const Map<TowerType, IconData> _icons = {
    TowerType.cannon: Icons.circle,
    TowerType.archer: Icons.gps_fixed,
    TowerType.mage: Icons.auto_fix_high,
    TowerType.flamethrower: Icons.local_fire_department,
    TowerType.sniper: Icons.center_focus_strong,
    TowerType.tesla: Icons.bolt,
  };

  static const Map<TowerType, String> _flavor = {
    TowerType.cannon: 'Lobs a heavy shell that splashes every enemy nearby.',
    TowerType.archer: 'Fires fast, precise arrows at anything in range.',
    TowerType.mage: 'Hurls bolts of magic that scorch a small area.',
    TowerType.flamethrower: 'Sears every enemy that dares walk through its cone.',
    TowerType.sniper: 'Long-range precision — hits hard from the back row.',
    TowerType.tesla: 'Arcs lightning that chains between nearby enemies.',
  };

  @override
  Widget build(BuildContext context) {
    // Towers have no persistent unlock in this game — any of them can be
    // built in battle once you can afford it — so this tab is always fully
    // revealed. It's shown alongside Army/Bestiary as the reference page
    // for what each one does, not a lock-and-unlock gallery.
    final types = TowerType.values;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: types.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) return _ProgressStrip(unlocked: types.length, total: types.length);
        final type = types[i - 1];
        final def = TowerData.defFor(type);
        final stat = def.statAt(1);
        return CollectionEntryCard(
          icon: _icons[type]!,
          spriteName: 'tower_${type.name}',
          accentColor: AppColors.diamondBlue,
          name: def.displayName,
          statsLine: 'Cost ${def.buildCost} 🪙 • DMG ${stat.damage} • Range ${stat.range.toStringAsFixed(1)}',
          flavorText: _flavor[type]!,
          locked: false,
        );
      },
    );
  }
}

class _BestiaryTab extends StatelessWidget {
  const _BestiaryTab();

  static const Map<EnemyType, IconData> _icons = {
    EnemyType.skeleton: Icons.groups,
    EnemyType.skeletonArcher: Icons.gps_fixed,
    EnemyType.goblin: Icons.sports_martial_arts,
    EnemyType.lizard: Icons.bolt,
    EnemyType.monster: Icons.warning_amber,
    EnemyType.stormKnight: Icons.shield,
    EnemyType.emberHound: Icons.local_fire_department,
    EnemyType.stormCaller: Icons.flash_on,
    EnemyType.thunderTitan: Icons.thunderstorm,
    EnemyType.blackDragon: Icons.whatshot,
  };

  static const Map<EnemyType, String> _flavor = {
    EnemyType.skeleton: 'A shambling foot-soldier risen to swell the horde.',
    EnemyType.skeletonArcher: 'Keeps its distance and peppers the line with arrows.',
    EnemyType.goblin: 'Small, quick and cackling. Never alone — a pack of them swarms whoever they reach first.',
    EnemyType.lizard: 'Savage and armored — tears through your army with fangs and claws. Very hard to beat.',
    EnemyType.monster: 'A slow, hulking brute that soaks damage and hits like a truck.',
    EnemyType.stormKnight: 'Storm-forged plate armor. Shrugs off blows and sweeps whole squads aside.',
    EnemyType.emberHound: 'A burning hellhound — fragile, but lightning fast and never alone.',
    EnemyType.stormCaller: 'Hurls lightning from far away. Kill it before it picks your army apart.',
    EnemyType.thunderTitan: 'A walking thunderhead with enormous health. Arrives with every boss wave.',
    EnemyType.blackDragon: 'A black dragon that circles above the battle and burns your army with fire. Comes with the boss waves.',
  };

  /// Simple, self-contained "have I seen this yet" heuristic — no new save
  /// data needed. Skeleton shows up from the very first battle; the archer
  /// variant is held back as a reveal until the player has actually made
  /// some progress (more than the first level unlocked, or a decent
  /// Endless run), rather than dumping the whole bestiary on day one.
  bool _discovered(EnemyType type, PlayerProgress progress) {
    if (type == EnemyType.skeleton) return true;
    if (type == EnemyType.stormKnight ||
        type == EnemyType.emberHound ||
        type == EnemyType.stormCaller ||
        type == EnemyType.thunderTitan) {
      // Storm-only enemies are revealed once a Thunderstorm level has been cleared.
      return progress.unlockedLevelIds
          .contains(LevelData.idFor(Chapter.thunderstorm, 2));
    }
    return progress.unlockedLevelIds.length > 1 || progress.highestEndlessWave >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<StateProvider>().progress;
    final types = EnemyType.values;
    final discoveredCount = types.where((t) => _discovered(t, progress)).length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: types.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) return _ProgressStrip(unlocked: discoveredCount, total: types.length);
        final type = types[i - 1];
        final def = EnemyData.defFor(type);
        final locked = !_discovered(type, progress);
        return CollectionEntryCard(
          icon: _icons[type]!,
          spriteName: def.spriteName,
          accentColor: AppColors.crimsonEvil,
          name: def.displayName,
          statsLine: 'HP ${def.hp} • DMG ${def.damage} • Reward ${def.coinReward} 🪙',
          flavorText: _flavor[type]!,
          locked: locked,
          lockedHint: 'Keep playing to encounter this enemy',
        );
      },
    );
  }
}
