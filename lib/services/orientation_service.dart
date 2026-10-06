import 'package:flutter/services.dart';

/// The whole app is portrait. Only the battle and the town screens are
/// landscape: they call enterLandscape() when they open and leaveLandscape()
/// when they close. A counter makes sure a screen opened on top of another
/// landscape screen (e.g. replaying a battle) never rotates back by mistake.
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
  bool _isLandscape = false; // main() starts the app in portrait

  void enterLandscape() {
    _landscapeCount++;
    _apply();
  }

  void leaveLandscape() {
    if (_landscapeCount > 0) _landscapeCount--;
    _apply();
  }

  void _apply() {
    final landscape = _landscapeCount > 0;
    if (landscape == _isLandscape) return;
    _isLandscape = landscape;
    SystemChrome.setPreferredOrientations(landscape ? _landscape : _portrait);
  }
}
