// Shown when the player taps the hamburger icon (top-right, BattleScreen).
// The battle is already paused by the time this appears (BattleScreen pauses
// it before setting _showPauseMenu = true) and stays paused for as long as
// this whole flow — including the nested Home/Quit confirmations — is open.
//
// Flow this implements exactly as specified:
//   Resume  -> plays a 3-2-1 countdown, then actually unpauses
//   Settings-> pushes SettingsScreen (battle stays paused underneath)
//   Home    -> "Are you sure you want to Leave?" (Yes/Cancel)
//                Yes -> "Are you sure you want to Lose Progress?" (Yes/Cancel)
//                  Yes -> exit to the main menu
//                  Cancel -> back to this pause menu
//                Cancel -> back to this pause menu
//   Quit    -> same two-step confirmation, wording says "Quit" first, then
//              exits to the same start/main-menu screen (this app has no
//              separate splash screen — MainMenuScreen is both).
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../screens/formation_screen.dart';
import '../screens/settings_screen.dart';
import '../services/sound_service.dart';

class PauseMenuOverlay extends StatefulWidget {
  final VoidCallback onResumed;
  final VoidCallback onExit; // Home or Quit both end up here

  const PauseMenuOverlay({super.key, required this.onResumed, required this.onExit});

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
  int? _countdown; // null = not resuming yet; 3,2,1 while counting down

  void _startResumeCountdown() async {
    SoundService.instance.playButtonTap();
    for (final n in [3, 2, 1]) {
      setState(() => _countdown = n);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    widget.onResumed();
  }

  Future<bool> _confirm(String question) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.royalGold, width: 1.5),
        ),
        content: Text(question, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false; // dismissed any other way == Cancel
  }

  /// Shared by Home and Quit — both ask "are you sure you want to <verb>?"
  /// then, only if that's confirmed, ask the shared "lose progress?" question.
  Future<void> _confirmLeave(String firstQuestion) async {
    final wantsToLeave = await _confirm(firstQuestion);
    if (!wantsToLeave || !mounted) return;
    final confirmedLossOfProgress = await _confirm('Are you sure you want to Lose Progress?');
    if (confirmedLossOfProgress) {
      widget.onExit();
    }
    // Cancel at either step: dialogs are closed, this pause menu stays open.
  }

  @override
  Widget build(BuildContext context) {
    if (_countdown != null) {
      return Container(
        color: Colors.black.withOpacity(0.8),
        alignment: Alignment.center,
        child: Text(
          '$_countdown',
          style: const TextStyle(color: AppColors.royalGold, fontSize: 96, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      color: Colors.black.withOpacity(0.75),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 60),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.royalGold, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PAUSED', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startResumeCountdown,
                icon: const Icon(Icons.play_arrow),
                label: const Text('RESUME'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService.instance.playButtonTap();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FormationScreen()),
                  );
                },
                icon: const Icon(Icons.grid_view),
                label: const Text('FORMATION'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService.instance.playButtonTap();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('SETTINGS'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService.instance.playButtonTap();
                  _confirmLeave('Are you sure you want to Leave?');
                },
                icon: const Icon(Icons.home),
                label: const Text('HOME'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService.instance.playButtonTap();
                  _confirmLeave('Are you sure you want to Quit?');
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('QUIT'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
