// Wraps shared_preferences to persist PlayerProgress (models/player_progress.dart)
// as a single JSON string under one key. Pure Dart aside from the
// shared_preferences dependency — no Flutter widget/BuildContext coupling,
// so it can be called from main.dart on boot and from StateProvider after
// any mutation (coins spent, chest opened, castle upgraded, settings changed).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_progress.dart';

class SaveService {
  SaveService._();
  static final SaveService instance = SaveService._();

  static const String _progressKey = 'kingdom_wars_player_progress';
  // When the save last REALLY changed (ms since epoch). Used by CloudSync to
  // decide whether the cloud copy or this device's copy is newer.
  static const String _savedAtKey = 'kingdom_wars_saved_at_ms';

  SharedPreferences? _prefsCache;

  Future<SharedPreferences> get _prefs async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  /// Loads saved progress from disk. Returns a fresh [PlayerProgress]
  /// (starting coins/diamonds, level 1 unlocked) if nothing has been
  /// saved yet, or if the saved data is corrupt/unreadable.
  Future<PlayerProgress> load() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_progressKey);
      if (raw == null || raw.isEmpty) {
        return PlayerProgress();
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PlayerProgress.fromJson(decoded);
    } catch (_) {
      // Corrupt save data should never crash the app on boot.
      return PlayerProgress();
    }
  }

  /// Serializes [progress] to JSON and writes it to disk. Safe to call
  /// frequently (e.g. after every StateProvider mutation) — writes are
  /// cheap string puts and shared_preferences batches them internally.
  Future<bool> save(PlayerProgress progress) async {
    try {
      final prefs = await _prefs;
      final raw = jsonEncode(progress.toJson());
      final old = prefs.getString(_progressKey);
      if (old == raw) return true; // nothing changed: keep the old timestamp
      final ok = await prefs.setString(_progressKey, raw);
      // A brand-new default save (fresh install / reset) must not look "newer"
      // than a real cloud save, so it does not get a timestamp.
      if (ok && raw != _defaultRaw) {
        await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  static final String _defaultRaw = jsonEncode(PlayerProgress().toJson());

  /// Time of the last real change to the save (0 = never / fresh install).
  Future<int> savedAtMs() async {
    try {
      final prefs = await _prefs;
      return prefs.getInt(_savedAtKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Marks the save as changed right now (used by Reset Progress, so the
  /// reset wins over the old cloud copy).
  Future<void> markChanged() async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Wipes all saved progress. Used by the "Reset Progress" action in
  /// SettingsScreen after the user confirms.
  Future<bool> clear() async {
    try {
      final prefs = await _prefs;
      return await prefs.remove(_progressKey);
    } catch (_) {
      return false;
    }
  }
}
