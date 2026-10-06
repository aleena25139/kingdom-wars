// Thin wrapper around flame_audio for music + SFX playback. Singleton so
// screens/widgets can call it directly (SoundService.instance.playButtonTap(),
// .playCue(), .playMusic()) without threading it through Provider. Respects
// PlayerProgress.musicEnabled / sfxEnabled.
//
// Audio files (all under assets/audio/, registered in pubspec.yaml):
//   music/game_music.mp3      background music (menu + battle)
//   sfx/game_buttons.mp3      every button tap
//   sfx/game_vfx.mp3          generic "something happened" sound
//   sfx/*.wav                 one file per SoundCue (creature voices, fight
//                             sounds) â€” see _cues below. Drop in your own
//                             file with the same name to replace any of them.
//
// Mixing rules, so the game never turns into noise:
//   * Fight sounds are quiet (0.2-0.3), creature voices a bit louder (0.45-0.6).
//   * Every cue has its own minimum gap, and there is a cap on how many
//     fight / voice sounds can overlap, so a big battle stays readable.
//   * DUCKING: while any sound effect or button click plays, the background
//     music is turned down clearly (voices a lot, small fight sounds less)
//     and fades back up smoothly afterwards.
import 'dart:async';
import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

import '../models/sound_cue.dart';

enum _Kind { voice, fight }

class _CueCfg {
  final String file;
  final double volume;
  final int gapMs; // min time between two plays of this cue
  final int durMs; // approx. length of the clip
  final double duck; // music volume while this plays (music base is 0.5)
  final _Kind kind;
  const _CueCfg(this.file, this.volume, this.gapMs, this.durMs, this.duck, this.kind);
}

class SoundService with WidgetsBindingObserver {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _musicTrack = 'music/game_music.mp3';
  static const String _buttonSfx = 'sfx/game_buttons.mp3';
  static const String _vfxSfx = 'sfx/game_vfx.mp3';

  static const double _musicVolume = 0.5;

  static const Map<SoundCue, _CueCfg> _cues = {
    // ---- your army ----
    SoundCue.arrowShot: _CueCfg('sfx/arrow_shot.wav', 0.22, 240, 300, 0.24, _Kind.fight),
    SoundCue.swordClash: _CueCfg('sfx/sword_clash.wav', 0.24, 280, 500, 0.24, _Kind.fight),
    SoundCue.mageZap: _CueCfg('sfx/mage_zap.wav', 0.24, 320, 400, 0.24, _Kind.fight),
    SoundCue.fireWhoosh: _CueCfg('sfx/fire_whoosh.wav', 0.26, 900, 900, 0.22, _Kind.fight),
    SoundCue.dragonRoar: _CueCfg('sfx/dragon_roar.wav', 0.50, 3500, 1300, 0.10, _Kind.voice),
    SoundCue.phoenixCry: _CueCfg('sfx/phoenix_cry.wav', 0.45, 3500, 1000, 0.10, _Kind.voice),
    SoundCue.pandaRoar: _CueCfg('sfx/panda_roar.wav', 0.45, 3000, 550, 0.11, _Kind.voice),
    SoundCue.pandaHit: _CueCfg('sfx/panda_hit.wav', 0.30, 450, 280, 0.23, _Kind.fight),
    SoundCue.healChime: _CueCfg('sfx/heal_chime.wav', 0.28, 1500, 900, 0.24, _Kind.fight),
    SoundCue.deployHorn: _CueCfg('sfx/deploy_horn.wav', 0.40, 400, 600, 0.12, _Kind.voice),
    // ---- enemies ----
    SoundCue.skeletonRattle: _CueCfg('sfx/skeleton_rattle.wav', 0.20, 450, 500, 0.25, _Kind.fight),
    SoundCue.goblinCackle: _CueCfg('sfx/goblin_cackle.wav', 0.40, 4000, 770, 0.12, _Kind.voice),
    SoundCue.goblinHit: _CueCfg('sfx/goblin_hit.wav', 0.24, 400, 180, 0.24, _Kind.fight),
    SoundCue.lizardRoar: _CueCfg('sfx/lizard_roar.wav', 0.55, 3500, 1100, 0.10, _Kind.voice),
    SoundCue.lizardBite: _CueCfg('sfx/lizard_bite.wav', 0.30, 500, 350, 0.23, _Kind.fight),
    SoundCue.monsterGrowl: _CueCfg('sfx/monster_growl.wav', 0.50, 3000, 1000, 0.10, _Kind.voice),
    SoundCue.titanRoar: _CueCfg('sfx/titan_roar.wav', 0.60, 4500, 1800, 0.10, _Kind.voice),
    SoundCue.houndBark: _CueCfg('sfx/hound_bark.wav', 0.30, 600, 220, 0.23, _Kind.fight),
    // ---- general ----
    SoundCue.hitThud: _CueCfg('sfx/hit_thud.wav', 0.22, 260, 300, 0.25, _Kind.fight),
    SoundCue.explosion: _CueCfg('sfx/explosion.wav', 0.34, 700, 1100, 0.19, _Kind.fight),
    SoundCue.thunder: _CueCfg('sfx/thunder.wav', 0.34, 1200, 1600, 0.19, _Kind.fight),
  };

  static const int _maxFightOverlap = 3;
  static const int _maxVoiceOverlap = 2;
  static const int _globalFightGapMs = 90;
  static const int _globalVoiceGapMs = 350;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _initialized = false;
  bool _musicShouldBePlaying = false;
  bool _bgmStarted = false; // music really started (not blocked by the browser)
  bool _gestureSeen = false; // the player has tapped/clicked at least once

  AudioPool? _buttonPool; // reusable players: short click plays reliably
  final Map<SoundCue, int> _lastPlayedMs = {};
  final List<int> _fightEnds = [];
  final List<int> _voiceEnds = [];
  int _lastFightMs = 0;
  int _lastVoiceMs = 0;
  int _lastButtonMs = 0;

  // ---- ducking state ----
  double _currentMusicVol = _musicVolume;
  double _duckLevel = _musicVolume;
  int _duckUntilMs = 0;
  Timer? _duckTimer;

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Loads every audio file into flame_audio's cache up front so first
  /// playback has no hitch. Call once from the loading screen.
  Future<void> preload() async {
    if (_initialized) return;
    // Android: by default every sound effect grabs "audio focus", which
    // silences / stops the background music. Mix with others instead, so music
    // keeps playing while clicks and battle sounds play on top of it.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('SoundService: could not set audio context ($e)');
    }
    try {
      FlameAudio.bgm.initialize(); // pauses / resumes music with the app
    } catch (_) {}
    _attachLifecycle();
    final files = <String>[
      _musicTrack,
      _buttonSfx,
      _vfxSfx,
      ...{for (final c in _cues.values) c.file},
    ];
    for (final f in files) {
      try {
        await FlameAudio.audioCache.load(f);
      } catch (e) {
        // A missing file shouldn't crash the app â€” that sound just stays silent.
        // The console tells you WHICH file is missing / not in pubspec.yaml.
        debugPrint('SoundService: could not load assets/audio/$f ($e)');
      }
    }
    try {
      _buttonPool = await FlameAudio.createPool(_buttonSfx, maxPlayers: 4);
    } catch (e) {
      debugPrint('SoundService: could not create button pool ($e)');
    }
    _initialized = true;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _bgmStarted = false;
      FlameAudio.bgm.stop();
    } else if (_musicShouldBePlaying) {
      _playBgm();
    }
  }

  void setSfxEnabled(bool enabled) => _sfxEnabled = enabled;
  // ---- app lifecycle: music must stop when the player leaves the game ----
  bool _lifecycleAttached = false;
  bool _pausedByApp = false;

  void _attachLifecycle() {
    if (_lifecycleAttached) return;
    _lifecycleAttached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Home button, recent apps, screen off, or another app in front.
        _pausedByApp = true;
        try {
          FlameAudio.bgm.pause();
        } catch (_) {}
        try {
          FlameAudio.bgm.audioPlayer.pause();
        } catch (_) {}
        break;
      case AppLifecycleState.resumed:
        if (!_pausedByApp) return;
        _pausedByApp = false;
        if (_musicShouldBePlaying && _musicEnabled) {
          if (_bgmStarted) {
            try {
              FlameAudio.bgm.resume();
            } catch (_) {}
          } else {
            _playBgm();
          }
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void applySettings({required bool musicEnabled, required bool sfxEnabled}) {
    _sfxEnabled = sfxEnabled;
    setMusicEnabled(musicEnabled);
  }

  void playMusic() {
    _musicShouldBePlaying = true;
    _playBgm();
  }

  void playMenuMusic() => playMusic();
  void playBattleMusic() => playMusic();

  void stopMusic() {
    _musicShouldBePlaying = false;
    _bgmStarted = false;
    FlameAudio.bgm.stop();
  }

  Future<void> _playBgm() async {
    if (_pausedByApp) return; // app is in the background: stay silent
    if (!_musicEnabled) return;
    // Already playing: do not restart the song when another screen asks again.
    if (_bgmStarted && FlameAudio.bgm.isPlaying) return;
    try {
      _currentMusicVol = _duckActive ? _duckLevel : _musicVolume;
      await FlameAudio.bgm.play(_musicTrack, volume: _currentMusicVol);
      _bgmStarted = true;
    } catch (e) {
      _bgmStarted = false;
      debugPrint('SoundService: music could not start yet ($e)');
    }
  }

  /// Call on every tap / click (see main.dart). Browsers (Chrome) do not allow
  /// sound before the player touches the page, so on the web the menu music
  /// is (re)started by the very first tap. On phones / desktop the music
  /// already started by itself and nothing happens here.
  void onUserGesture() {
    if (_gestureSeen) {
      // later taps: only retry if music should be on but is not running
      if (_musicShouldBePlaying && _musicEnabled && !_bgmStarted) _playBgm();
      return;
    }
    _gestureSeen = true;
    if (!_musicShouldBePlaying || !_musicEnabled) return;
    if (kIsWeb) {
      // The earlier attempt was blocked by the browser: start cleanly now.
      _bgmStarted = false;
      try {
        FlameAudio.bgm.stop();
      } catch (_) {}
      _playBgm();
    } else if (!_bgmStarted) {
      _playBgm();
    }
  }

  // ------------------------------------------------------------------
  // Sound effects
  // ------------------------------------------------------------------

  /// Every button tap. Also lowers the music a little while the click plays.
  void playButtonTap({double volume = 1.0}) {
    if (!_sfxEnabled) return;
    // Two handlers firing for the same tap (e.g. a button + the page it
    // closes) must still sound like ONE click.
    if (_nowMs() - _lastButtonMs < 120) return;
    _lastButtonMs = _nowMs();
    _duck(0.12, 650);
    final pool = _buttonPool;
    if (pool != null) {
      pool.start(volume: (0.8 * volume).clamp(0.0, 1.0).toDouble()).then<void>((_) {}, onError: (Object e) {
        debugPrint('SoundService: button pool failed ($e), using fallback');
        _playFile(_buttonSfx, 0.8 * volume);
      });
    } else {
      _playFile(_buttonSfx, 0.8 * volume);
    }
  }

  /// Click for the AppBar's automatic back arrow (no handler of ours runs
  /// there). Skipped when a button click just played, so buttons that also
  /// close their screen don't click twice.
  void playBackTap() {
    if (_nowMs() - _lastButtonMs < 400) return;
    playButtonTap();
  }

  /// Generic "something happened" sound (chest opened, victory, defeat...).
  void playVfx({double volume = 1.0}) {
    if (!_sfxEnabled) return;
    _duck(0.10, 1100);
    _playFile(_vfxSfx, 0.8 * volume);
  }

  /// One battle sound (creature voice / fight sound). Throttled, quiet, and
  /// ducks the music while it plays.
  void playCue(SoundCue cue) {
    if (!_sfxEnabled) return;
    final cfg = _cues[cue];
    if (cfg == null) return;
    final now = _nowMs();

    final last = _lastPlayedMs[cue] ?? 0;
    if (now - last < cfg.gapMs) return;

    final ends = cfg.kind == _Kind.voice ? _voiceEnds : _fightEnds;
    ends.removeWhere((e) => e <= now);
    if (cfg.kind == _Kind.voice) {
      if (ends.length >= _maxVoiceOverlap || now - _lastVoiceMs < _globalVoiceGapMs) return;
      _lastVoiceMs = now;
    } else {
      if (ends.length >= _maxFightOverlap || now - _lastFightMs < _globalFightGapMs) return;
      _lastFightMs = now;
    }

    _lastPlayedMs[cue] = now;
    ends.add(now + cfg.durMs);
    _duck(cfg.duck, cfg.durMs + (cfg.kind == _Kind.voice ? 350 : 200));
    _playFile(cfg.file, cfg.volume);
  }

  /// Plays a cue after a delay (used for the army's battle cries at the
  /// start of a fight, so the voices come one after another).
  void playCueDelayed(SoundCue cue, int delayMs) {
    Future<void>.delayed(Duration(milliseconds: delayMs), () => playCue(cue));
  }

  void _playFile(String file, double volume) {
    try {
      FlameAudio.play(file, volume: volume.clamp(0.0, 1.0).toDouble()).then<void>((_) {}, onError: (Object e) {
        debugPrint('SoundService: could not play assets/audio/$file ($e)');
      });
    } catch (e) {
      debugPrint('SoundService: could not play assets/audio/$file ($e)');
    }
  }

  // ------------------------------------------------------------------
  // Music ducking
  // ------------------------------------------------------------------

  bool get _duckActive => _nowMs() < _duckUntilMs;

  void _duck(double level, int holdMs) {
    if (!_musicEnabled || !_musicShouldBePlaying) return;
    final now = _nowMs();
    if (now >= _duckUntilMs) {
      _duckLevel = level; // previous duck is over: start fresh
    } else {
      _duckLevel = math.min(_duckLevel, level); // deepest request wins
    }
    _duckUntilMs = math.max(_duckUntilMs, now + holdMs);
    _duckTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) => _tickDuck());
  }

  void _tickDuck() {
    final active = _duckActive;
    final target = active ? _duckLevel : _musicVolume;
    var v = _currentMusicVol;
    if (v > target) {
      v = math.max(target, v - 0.15); // dip almost instantly
    } else if (v < target) {
      v = math.min(target, v + 0.015); // come back up smoothly
    }
    if (v != _currentMusicVol) {
      _currentMusicVol = v;
      try {
        FlameAudio.bgm.audioPlayer.setVolume(v).catchError((_) {});
      } catch (_) {}
    }
    if (!active && v >= _musicVolume - 0.0001) {
      _duckTimer?.cancel();
      _duckTimer = null;
      _duckLevel = _musicVolume;
    }
  }

  void dispose() {
    _duckTimer?.cancel();
    _duckTimer = null;
    FlameAudio.bgm.stop();
  }
}
