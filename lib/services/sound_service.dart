// Music + SFX for the whole game (singleton: SoundService.instance).
//
// REWRITTEN to fix:
//  * music stuttering / stopping   -> ONE music player that is created once and
//    only ever paused / resumed (never stopped + recreated). A watchdog restarts
//    it if the OS pauses it behind our back.
//  * music dead after OFF -> ON    -> toggling just pauses / resumes that player.
//  * button clicks not audible     -> short clicks use pre-created players
//    (no SoundPool / no new player per click).
//  * voices arriving late / piling -> SFX use a small fixed set of reusable
//    players (round-robin) instead of creating a new AudioPlayer per sound,
//    plus hard caps on how many voices / fight sounds can overlap.
//  * music volume down while any SFX or button plays (ducking), fades back up.
//
// Audio files (assets/audio/, registered in pubspec.yaml) are unchanged:
//   music/game_music.mp3, sfx/game_buttons.mp3, sfx/game_vfx.mp3, sfx/*.wav
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

/// A few reusable players used round-robin (no player is created while playing).
class _PlayerPool {
  final List<AudioPlayer> _players;
  int _next = 0;
  _PlayerPool(int size, AudioContext? ctx)
      : _players = List.generate(size, (_) {
          final p = AudioPlayer();
          p.setReleaseMode(ReleaseMode.stop).catchError((Object _) {});
          if (ctx != null) p.setAudioContext(ctx).catchError((Object _) {});
          return p;
        });

  void play(Source source, double volume, String label) {
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    p.play(source, volume: volume.clamp(0.0, 1.0).toDouble()).catchError((Object e) {
      debugPrint('SoundService: could not play $label ($e)');
    });
  }

  void stopAll() {
    for (final p in _players) {
      p.stop().catchError((Object _) {});
    }
  }
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

  // Fewer overlapping sounds = no "everything comes late" pile-up.
  static const int _maxFightOverlap = 3;
  static const int _maxVoiceOverlap = 2;
  static const int _globalFightGapMs = 110;
  static const int _globalVoiceGapMs = 450;

  // ---- state ----
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _initialized = false;
  bool _musicShouldBePlaying = false; // a screen asked for music
  bool _pausedByApp = false; // app is in the background
  bool _musicLoaded = false; // the music source was handed to the player once
  bool _musicStarting = false;
  bool _lifecycleAttached = false;
  int _battleToken = 0; // delayed battle cries from an old battle are dropped

  AudioContext? _ctx;
  AudioPlayer? _music;
  StreamSubscription<PlayerState>? _musicStateSub;
  Timer? _watchdog;

  final Map<String, Source> _sources = {};
  _PlayerPool? _buttonPool;
  _PlayerPool? _vfxPool;
  _PlayerPool? _fightPool;
  _PlayerPool? _voicePool;

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

  bool get _wantMusic => _musicEnabled && _musicShouldBePlaying && !_pausedByApp && _initialized;

  // ------------------------------------------------------------------
  // Setup
  // ------------------------------------------------------------------

  /// Call once from the loading screen.
  Future<void> preload() async {
    if (_initialized) return;

    // Android: never grab audio focus (it would silence the music whenever a
    // click plays). Mix with whatever else is playing instead.
    try {
      _ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      await AudioPlayer.global.setAudioContext(_ctx!);
    } catch (e) {
      debugPrint('SoundService: could not set audio context ($e)');
    }

    _attachLifecycle();

    final files = <String>{
      _musicTrack,
      _buttonSfx,
      _vfxSfx,
      for (final c in _cues.values) c.file,
    };
    for (final f in files) {
      try {
        _sources[f] = await _buildSource(f);
      } catch (e) {
        // Missing file: that sound stays silent, the game keeps running.
        debugPrint('SoundService: could not load assets/audio/$f ($e)');
      }
    }

    // One dedicated music player, created ONCE.
    try {
      final m = AudioPlayer();
      await m.setReleaseMode(ReleaseMode.loop);
      if (_ctx != null) await m.setAudioContext(_ctx!);
      await m.setVolume(_musicVolume);
      _music = m;
      _musicStateSub = m.onPlayerStateChanged.listen(_onMusicState);
    } catch (e) {
      debugPrint('SoundService: could not create music player ($e)');
    }

    _buttonPool = _PlayerPool(3, _ctx);
    _vfxPool = _PlayerPool(2, _ctx);
    _fightPool = _PlayerPool(_maxFightOverlap + 1, _ctx);
    _voicePool = _PlayerPool(_maxVoiceOverlap + 1, _ctx);

    _initialized = true;

    // Music watchdog: if music should be on but the OS paused/stopped it, resume.
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _ensureMusic());

    if (_musicShouldBePlaying) _ensureMusic();
  }

  /// Local path / url of an asset copy that the audio player can read.
  Future<Source> _buildSource(String file) async {
    final dynamic loaded = await FlameAudio.audioCache.load(file);
    final String path = loaded is Uri
        ? (kIsWeb ? loaded.toString() : loaded.toFilePath())
        : (loaded as dynamic).path as String;
    return kIsWeb ? UrlSource(path) : DeviceFileSource(path);
  }

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------

  void applySettings({required bool musicEnabled, required bool sfxEnabled}) {
    _sfxEnabled = sfxEnabled;
    setMusicEnabled(musicEnabled);
  }

  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
    if (!enabled) stopAllSfx();
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _pauseMusic();
    } else {
      _musicShouldBePlaying = true;
      _ensureMusic();
    }
  }

  // ------------------------------------------------------------------
  // Music
  // ------------------------------------------------------------------

  void playMusic() {
    _musicShouldBePlaying = true;
    _ensureMusic();
  }

  void playMenuMusic() => playMusic();
  void playBattleMusic() => playMusic();

  void stopMusic() {
    _musicShouldBePlaying = false;
    _pauseMusic();
  }

  void _pauseMusic() {
    final m = _music;
    if (m == null) return;
    m.pause().catchError((Object _) {});
  }

  void _onMusicState(PlayerState s) {
    // The OS (or a phone call, other app...) paused us but we still want music.
    if ((s == PlayerState.paused || s == PlayerState.stopped) && _wantMusic) {
      Future<void>.delayed(const Duration(milliseconds: 400), _ensureMusic);
    }
  }

  /// Makes sure the music is playing if it should be. Safe to call any time,
  /// as often as you like: it never restarts a song that is already playing.
  Future<void> _ensureMusic() async {
    final m = _music;
    if (m == null || !_wantMusic || _musicStarting) return;
    if (m.state == PlayerState.playing) return;
    final src = _sources[_musicTrack];
    if (src == null) return;
    _musicStarting = true;
    try {
      _currentMusicVol = _duckActive ? _duckLevel : _musicVolume;
      await (() async {
        if (_musicLoaded && m.state == PlayerState.paused) {
          await m.setVolume(_currentMusicVol);
          await m.resume();
        } else {
          await m.stop();
          await m.play(src, volume: _currentMusicVol);
          _musicLoaded = true;
        }
      })().timeout(const Duration(seconds: 3));
    } catch (e) {
      _musicLoaded = false;
      debugPrint('SoundService: music restart ($e)');
    } finally {
      _musicStarting = false;
    }
  }

  /// Called on every tap (main.dart). Browsers only allow sound after a tap.
  void onUserGesture() {
    if (_wantMusic && _music?.state != PlayerState.playing) _ensureMusic();
  }

  // ---- app lifecycle: music stops when the player leaves the game ----
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
        _pausedByApp = true; // set first: the watchdog must not restart it
        _pauseMusic();
        stopAllSfx();
        break;
      case AppLifecycleState.resumed:
        if (!_pausedByApp) return;
        _pausedByApp = false;
        _ensureMusic();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ------------------------------------------------------------------
  // Sound effects
  // ------------------------------------------------------------------

  /// Every button tap. Also lowers the music while the click plays.
  void playButtonTap({double volume = 1.0}) {
    if (!_sfxEnabled) return;
    final now = _nowMs();
    // Two handlers for the same tap must still sound like ONE click.
    if (now - _lastButtonMs < 120) return;
    _lastButtonMs = now;
    _duck(0.12, 700);
    _playOn(_buttonPool, _buttonSfx, 1.0 * volume);
  }

  /// Click for the AppBar's automatic back arrow.
  void playBackTap() {
    if (_nowMs() - _lastButtonMs < 400) return;
    playButtonTap();
  }

  /// Generic "something happened" sound (chest opened, victory, defeat...).
  void playVfx({double volume = 1.0}) {
    if (!_sfxEnabled) return;
    _duck(0.10, 1200);
    _playOn(_vfxPool, _vfxSfx, 0.9 * volume);
  }

  /// One battle sound. Throttled, quiet, and ducks the music while it plays.
  void playCue(SoundCue cue) {
    if (!_sfxEnabled || !_initialized) return;
    final cfg = _cues[cue];
    if (cfg == null) return;
    final now = _nowMs();

    final last = _lastPlayedMs[cue] ?? 0;
    if (now - last < cfg.gapMs) return;

    final isVoice = cfg.kind == _Kind.voice;
    final ends = isVoice ? _voiceEnds : _fightEnds;
    ends.removeWhere((e) => e <= now);
    if (isVoice) {
      if (ends.length >= _maxVoiceOverlap || now - _lastVoiceMs < _globalVoiceGapMs) return;
      // A voice is more important than a swarm of small fight sounds.
      _lastVoiceMs = now;
    } else {
      if (ends.length >= _maxFightOverlap || now - _lastFightMs < _globalFightGapMs) return;
      // Don't add small fight noises on top of a voice that is speaking.
      if (_voiceEnds.any((e) => e > now)) return;
      _lastFightMs = now;
    }

    _lastPlayedMs[cue] = now;
    ends.add(now + cfg.durMs);
    _duck(cfg.duck, cfg.durMs + (isVoice ? 350 : 200));
    _playOn(isVoice ? _voicePool : _fightPool, cfg.file, cfg.volume);
  }

  /// Plays a cue after a delay (army battle cries at the start of a fight).
  /// Dropped if the battle was left in the meantime.
  void playCueDelayed(SoundCue cue, int delayMs) {
    final token = _battleToken;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (token == _battleToken) playCue(cue);
    });
  }

  /// Call when a battle starts / ends (BattleScreen) so no old sounds linger.
  void battleEnded() {
    _battleToken++;
    stopAllSfx();
  }

  void stopAllSfx() {
    _fightPool?.stopAll();
    _voicePool?.stopAll();
    _fightEnds.clear();
    _voiceEnds.clear();
  }

  void _playOn(_PlayerPool? pool, String file, double volume) {
    final src = _sources[file];
    if (pool == null || src == null) return;
    pool.play(src, volume, file);
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
    _duckTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) => _tickDuck());
  }

  void _tickDuck() {
    final active = _duckActive;
    final target = active ? _duckLevel : _musicVolume;
    var v = _currentMusicVol;
    if (v > target) {
      v = math.max(target, v - 0.2); // dip almost instantly
    } else if (v < target) {
      v = math.min(target, v + 0.02); // come back up smoothly
    }
    if (v != _currentMusicVol) {
      _currentMusicVol = v;
      _music?.setVolume(v).catchError((Object _) {});
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
    _watchdog?.cancel();
    _watchdog = null;
    _musicStateSub?.cancel();
    _music?.stop().catchError((Object _) {});
  }
}
