import 'package:flutter/foundation.dart';

/// App-wide state shared across all 3 screens via Provider: coins and
/// player level for now. Health/wave/tower-placement state for the
/// battlefield itself will be added in Step 4 as its own provider (or
/// folded in here) once the game screen is built.
class GameState extends ChangeNotifier {
  int _coins = 1250;
  final int _playerLevel = 5;

  int get coins => _coins;
  int get playerLevel => _playerLevel;

  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }

  /// Returns true if the spend succeeded (i.e. enough coins were available).
  bool spendCoins(int amount) {
    if (_coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    return true;
  }
}
