import 'package:flutter/services.dart';

/// The whole app is portrait. Only the battle and the town screens are
/// landscape: they call enterLandscape() when they open and leaveLandscape()
/// when they close. A counter makes sure a screen opened on top of another
/// landscape screen (e.g. replaying a battle) never rotates back by mistake.
///
/// Every change is sent to Android/iOS again (no "already portrait" shortcut),
/// so the lock can never get out of sync with the real screen.
class OrientationService {
  OrientationService._();
  static final OrientationService instance = OrientationService._();

  static const _portrait = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
  static const _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  int _landscapeCount = 0;

  /// Call at app start (main) and from the splash screen.
  Future<void> forcePortrait() {
    _landscapeCount = 0;
    return SystemChrome.setPreferredOrientations(_portrait);
  }

  void enterLandscape() {
    _landscapeCount++;
    _apply();
  }

  void leaveLandscape() {
    if (_landscapeCount > 0) _landscapeCount--;
    _apply();
  }

  void _apply() {
    SystemChrome.setPreferredOrientations(_landscapeCount > 0 ? _landscape : _portrait);
  }
}
