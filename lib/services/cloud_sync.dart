// Keeps this device's save and the cloud save in step - without ever getting
// in the player's way.
//
//   * Offline-first: the game always saves to the phone (SaveService). The
//     cloud copy is only a backup / way to continue on another phone.
//   * The newest copy wins. On launch the cloud is checked once; if it holds a
//     newer save (e.g. played on another phone, or reinstalled) it is loaded,
//     otherwise this device's save is uploaded.
//   * Uploads are delayed ~8 s after the last change and retried every minute
//     while offline. No internet = nothing happens, no errors, no waiting.
//   * Nothing is uploaded before the first successful cloud check, so a fresh
//     install can never overwrite a good cloud save with an empty one.
import 'dart:async';

import '../models/player_progress.dart';
import 'firebase_service.dart';
import 'save_service.dart';

class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  PlayerProgress Function()? _getProgress;
  void Function(PlayerProgress)? _apply;
  bool Function()? _canApply;

  bool _checked = false; // cloud was read successfully at least once
  bool _busy = false;
  int _lastUploadedMs = -1;
  Timer? _debounce;
  Timer? _retry;

  void attach({
    required PlayerProgress Function() getProgress,
    required void Function(PlayerProgress) apply,
    required bool Function() canApply,
  }) {
    _getProgress = getProgress;
    _apply = apply;
    _canApply = canApply;
    _retry ??= Timer.periodic(const Duration(seconds: 60), (_) => _run());
  }

  /// Called right after the game has loaded (does nothing visible).
  void syncNow() => unawaited(_run());

  /// Called after every save change; uploads a few seconds later.
  void scheduleUpload() {
    if (_getProgress == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () => unawaited(_run()));
  }

  /// Publishes the best Endless score right away (after a run).
  void submitBestNow() {
    final get = _getProgress;
    if (get == null) return;
    unawaited(FirebaseService.instance.submitScore(get()));
  }

  Future<void> _run() async {
    final get = _getProgress;
    if (get == null || _busy) return;
    _busy = true;
    try {
      final fs = FirebaseService.instance;
      if (!await fs.ensureSignedIn()) return; // offline / not configured

      final localMs = await SaveService.instance.savedAtMs();

      if (!_checked) {
        final cloud = await fs.fetchSave(); // throws while offline
        if (cloud != null && cloud.updatedAtMs > localMs + 1000) {
          // The cloud copy is newer: use it (never in the middle of a battle).
          if (_canApply?.call() != true) return; // try again later
          _checked = true;
          _apply?.call(cloud.progress);
          await fs.submitScore(cloud.progress);
          return;
        }
        _checked = true;
      }

      if (localMs > 0 && localMs != _lastUploadedMs) {
        final p = get();
        if (await fs.uploadSave(p, localMs)) _lastUploadedMs = localMs;
        await fs.submitScore(p);
      }
    } catch (_) {
      // offline or server problem: stay quiet, the next retry will try again
    } finally {
      _busy = false;
    }
  }
}
