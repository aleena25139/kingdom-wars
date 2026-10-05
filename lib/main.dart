// App entry point. Locks orientation, then immediately runs the app showing
// SplashScreen (game logo) -> LoadingScreen (reads the save file + preloads
// audio) -> MainMenuScreen. StateProvider is created up-front with a
// placeholder PlayerProgress() and LoadingScreen swaps in the real saved
// data via provider.loadProgress() once SaveService finishes reading it, so
// every screen below MyApp can read coins/diamonds/progress and call
// battle/meta actions without prop-drilling from the very first frame.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'game_logic/state_provider.dart';
import 'screens/splash_screen.dart';
import 'services/cloud_sync.dart';
import 'services/firebase_service.dart';
import 'services/save_service.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Firebase (cloud save + global leaderboard) is optional and never blocks
  // the game: with no internet, or before Firebase is configured, it simply
  // stays off and the game runs offline exactly the same.
  unawaited(FirebaseService.instance.init());

  runApp(const KingdomWarsApp());
}

class KingdomWarsApp extends StatelessWidget {
  const KingdomWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateProvider>(
      create: (_) {
        final provider = StateProvider();
        // Persist to disk on every state change (coins spent, chest opened,
        // castle upgraded, settings changed, etc). shared_preferences writes
        // are cheap, so a save-on-every-notify approach is fine here.
        provider.addListener(() {
          SaveService.instance.save(provider.progress);
          CloudSync.instance.scheduleUpload(); // cloud backup, only when online
        });
        CloudSync.instance.attach(
          getProgress: () => provider.progress,
          canApply: () => !provider.gameEngine.hasActiveBattle,
          apply: (cloud) {
            provider.loadProgress(cloud);
            SoundService.instance.applySettings(
              musicEnabled: cloud.musicEnabled,
              sfxEnabled: cloud.sfxEnabled,
            );
          },
        );
        return provider;
      },
      child: MaterialApp(
        title: 'Kingdom Wars: Castle Defense',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        navigatorObservers: [_BackClickObserver()],
        // Browsers only allow sound after the first tap: this tells the
        // SoundService about every tap (it never blocks the tap itself).
        builder: (context, child) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => SoundService.instance.onUserGesture(),
          child: child,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

/// Plays the button click when a screen is closed with the AppBar back arrow.
class _BackClickObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) SoundService.instance.playBackTap();
  }
}
