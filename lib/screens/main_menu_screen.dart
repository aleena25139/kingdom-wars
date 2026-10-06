// The game's home screen. Animated castle-and-clouds background, a top HUD
// showing coins/diamonds/level/castle level, a 2-column grid of the 8 main
// navigation buttons, a bottom Campaign/Endless bar, and the floating
// treasure chest. All navigation targets are built in STEP 7.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../services/sound_service.dart';
import '../widgets/top_hud_bar.dart';
import '../widgets/treasure_chest_widget.dart';
import 'army_screen.dart';
import 'battle_map_screen.dart';
import 'battle_screen.dart';
import 'campaign_screen.dart';
import 'castle_upgrade_screen.dart';
import 'collection_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'town_screen.dart';
import 'treasure_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with TickerProviderStateMixin {
  late final AnimationController _cloudController;
  late final AnimationController _torchController;
  late final AnimationController _titleGlowController;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
    _torchController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _titleGlowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    SoundService.instance.playMusic();
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _torchController.dispose();
    _titleGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                const TopHudBar(),
                const SizedBox(height: 8),
                _buildTitle(),
                Expanded(child: _buildCenterButtons()),
                _buildBottomButtons(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 90,
            child: TreasureChestWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.menuBackgroundGradient,
            ),
          ),
          child: Stack(
            children: [
              for (int i = 0; i < 4; i++)
                Positioned(
                  top: 40.0 + i * 60,
                  left: (_cloudController.value * MediaQuery.of(context).size.width * (1 + i * 0.3)) %
                          (MediaQuery.of(context).size.width + 200) -
                      200,
                  child: Icon(Icons.cloud, size: 60 + i * 10.0, color: Colors.white.withValues(alpha: 0.08)),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Icon(Icons.castle, size: 160, color: AppColors.deepPurple.withValues(alpha: 0.5)),
              ),
              AnimatedBuilder(
                animation: _torchController,
                builder: (context, _) => Positioned(
                  bottom: 60,
                  left: 40,
                  child: Icon(
                    Icons.local_fire_department,
                    size: 28 + _torchController.value * 6,
                    color: AppColors.orange.withValues(alpha: 0.7 + _torchController.value * 0.3),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _torchController,
                builder: (context, _) => Positioned(
                  bottom: 60,
                  right: 40,
                  child: Icon(
                    Icons.local_fire_department,
                    size: 28 + (1 - _torchController.value) * 6,
                    color: AppColors.orange.withValues(alpha: 0.7 + (1 - _torchController.value) * 0.3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _titleGlowController,
      builder: (context, _) {
        final glow = 10 + _titleGlowController.value * 14;
        return Text(
          'KINGDOM WARS',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                shadows: [
                  Shadow(color: AppColors.lightGold, blurRadius: glow),
                  const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
        );
      },
    );
  }

  Widget _buildCenterButtons() {
    final buttons = <_MenuButtonData>[
      _MenuButtonData('BATTLE', Icons.gavel, () => _push(const BattleMapScreen())),
      _MenuButtonData('CASTLE', Icons.castle, () => _push(const CastleUpgradeScreen())),
      _MenuButtonData('ARMY', Icons.shield, () => _push(const ArmyScreen())),
      _MenuButtonData('TOWN', Icons.location_city, () => _push(const TownScreen())),
      _MenuButtonData('TREASURE', Icons.card_giftcard, () => _push(const TreasureScreen())),
      _MenuButtonData('COLLECTION', Icons.auto_stories, () => _push(const CollectionScreen())),
      _MenuButtonData('LEADERBOARD', Icons.emoji_events, () => _push(const LeaderboardScreen())),
      _MenuButtonData('SETTINGS', Icons.settings, () => _push(const SettingsScreen()), iconColor: AppColors.goldIcon),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 3.2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: buttons.map((b) => _MenuButton(data: b)).toList(),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _push(const CampaignScreen()),
              icon: const Icon(Icons.menu_book),
              label: const Text('CAMPAIGN'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                SoundService.instance.playButtonTap();
                context.read<StateProvider>().startEndless();
                _push(const BattleScreen());
              },
              icon: const Icon(Icons.all_inclusive),
              label: const Text('ENDLESS'),
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) {
    SoundService.instance.playButtonTap();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _MenuButtonData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  _MenuButtonData(this.label, this.icon, this.onTap, {this.iconColor = AppColors.textGold});
}

class _MenuButton extends StatelessWidget {
  final _MenuButtonData data;
  const _MenuButton({required this.data});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: data.onTap,
      icon: Icon(
        data.icon,
        color: data.iconColor,
        shadows: data.iconColor == AppColors.goldIcon
            ? [Shadow(color: AppColors.goldIcon.withValues(alpha: 0.7), blurRadius: 8)]
            : null,
      ),
      label: Text(data.label, overflow: TextOverflow.ellipsis),
    );
  }
}


