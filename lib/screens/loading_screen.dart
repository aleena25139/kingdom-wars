// Does the real work that main() used to do before runApp(): reads the save
// file and preloads audio. Kept as its own screen (rather than a blocking
// await before runApp) so the player sees themed UI immediately instead of
// a blank frame while I/O happens.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../game_logic/state_provider.dart';
import '../services/cloud_sync.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import 'main_menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final started = DateTime.now();

    final progress = await SaveService.instance.load();
    await SoundService.instance.preload();
    SoundService.instance.applySettings(
      musicEnabled: progress.musicEnabled,
      sfxEnabled: progress.sfxEnabled,
    );

    // A loading screen that flashes for 40ms reads as broken, not fast — pad
    // out to at least this long so the spinner is actually perceptible.
    const minDisplay = Duration(milliseconds: 700);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;
    context.read<StateProvider>().loadProgress(progress);
    CloudSync.instance.syncNow(); // background, silent; does nothing when offline
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainMenuScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.menuBackgroundGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.castle, size: 64, color: AppColors.royalGold),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.royalGold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppColors.textPrimary.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
