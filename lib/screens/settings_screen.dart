// Settings screen: music/SFX/vibration toggles, a difficulty selector, a
// confirm-gated progress reset, and an About/Credits entry. (The Language
// option was removed: the game's texts are English only, so a selector that
// changed nothing would have been misleading.) Every control clicks.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../models/player_progress.dart';
import '../services/sound_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final progress = provider.progress;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: AppColors.goldIcon),
            SizedBox(width: 8),
            Text('SETTINGS'),
          ],
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.music_note, color: AppColors.textGold),
            title: const Text('Music'),
            value: progress.musicEnabled,
            onChanged: (v) {
              SoundService.instance.playButtonTap();
              provider.updateSettings(musicEnabled: v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: AppColors.textGold),
            title: const Text('SFX'),
            value: progress.sfxEnabled,
            onChanged: (v) {
              // Click first when turning SFX on (so you hear it), and before
              // turning it off the click is still the last sound you hear.
              if (v) provider.updateSettings(sfxEnabled: v);
              SoundService.instance.playButtonTap();
              if (!v) provider.updateSettings(sfxEnabled: v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration, color: AppColors.textGold),
            title: const Text('Vibration'),
            value: progress.vibrationEnabled,
            onChanged: (v) {
              SoundService.instance.playButtonTap();
              provider.updateSettings(vibrationEnabled: v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune, color: AppColors.textGold),
            title: const Text('Difficulty'),
            trailing: DropdownButton<Difficulty>(
              value: progress.difficulty,
              dropdownColor: AppColors.deepPurple,
              items: const [
                DropdownMenuItem(value: Difficulty.easy, child: Text('Easy')),
                DropdownMenuItem(value: Difficulty.normal, child: Text('Normal')),
                DropdownMenuItem(value: Difficulty.hard, child: Text('Hard')),
              ],
              onChanged: (v) {
                SoundService.instance.playButtonTap();
                provider.updateSettings(difficulty: v);
              },
            ),
          ),
          const Divider(color: AppColors.royalGold),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.crimsonEvil),
            title: const Text('Reset Progress', style: TextStyle(color: AppColors.crimsonEvil)),
            onTap: () {
              SoundService.instance.playButtonTap();
              _confirmReset(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.textGold),
            title: const Text('About / Credits'),
            onTap: () {
              SoundService.instance.playButtonTap();
              _showAbout(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, StateProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        title: const Text('Reset Progress?'),
        content: const Text('This will erase all coins, diamonds, castle level, and campaign progress. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.of(ctx).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              provider.resetProgress();
              Navigator.of(ctx).pop();
            },
            child: const Text('RESET', style: TextStyle(color: AppColors.crimsonEvil)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Kingdom Wars: Castle Defense',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.castle, color: AppColors.royalGold, size: 40),
      children: const [
        Text('Built with Flutter + Flame.\nArt: Kenney Tower Defense Top-Down 2D pack.'),
      ],
    );
  }
}
