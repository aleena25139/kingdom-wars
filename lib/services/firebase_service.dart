// Thin wrapper around Firebase (anonymous login, Firestore). EVERYTHING here
// is best-effort: if Firebase isn't configured, the phone is offline, or any
// call fails/times out, the methods just return false/null and the game keeps
// running exactly as it does offline. Nothing in the game ever waits on this.
//
// Firestore layout (see firestore.rules):
//   users/{uid}        -> { data: <json string of PlayerProgress>, updatedAtMs, bestScore }
//   leaderboard/{uid}  -> { name, score, wave, updatedAt }
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/player_progress.dart';

class CloudSave {
  final PlayerProgress progress;
  final int updatedAtMs;
  const CloudSave(this.progress, this.updatedAtMs);
}

class LeaderEntry {
  final String uid;
  final String name;
  final int score;
  final int wave;
  const LeaderEntry({required this.uid, required this.name, required this.score, required this.wave});
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool ready = false;
  String? _uid;
  Future<void>? _initFuture;

  String? get uid => _uid;

  /// Starts Firebase once (safe to call many times). Never throws.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 10));
      // Keep a local copy of cloud data and queue writes made offline, so the
      // game behaves the same with and without internet.
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      ready = true;
    } catch (_) {
      ready = false; // not configured / failed: offline-only mode
    }
  }

  /// Anonymous login (no email/password for the player). Works offline if the
  /// player has logged in before, because Firebase remembers the user.
  Future<bool> ensureSignedIn() async {
    await init();
    if (!ready) return false;
    try {
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      user ??= (await auth.signInAnonymously().timeout(const Duration(seconds: 8))).user;
      _uid = user?.uid;
      return _uid != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- cloud save

  /// Reads the cloud save from the SERVER. Returns null when there is none
  /// yet. THROWS when it can't reach the server (offline) - callers treat that
  /// as "try again later".
  Future<CloudSave?> fetchSave() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    if (!snap.exists) return null;
    final d = snap.data();
    final raw = d?['data'];
    if (raw is! String) return null;
    final progress = PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return CloudSave(progress, (d?['updatedAtMs'] as num?)?.toInt() ?? 0);
  }

  Future<bool> uploadSave(PlayerProgress progress, int savedAtMs) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'data': jsonEncode(progress.toJson()),
        'updatedAtMs': savedAtMs,
        'bestScore': progress.highestEndlessScore,
      }).timeout(const Duration(seconds: 6));
      return true;
    } catch (_) {
      // A timeout while offline is fine: Firestore keeps the write queued
      // and sends it as soon as the internet is back.
      return false;
    }
  }

  // --------------------------------------------------------------- leaderboard

  String displayNameFor(PlayerProgress p) {
    var n = p.playerName.trim();
    if (n.isEmpty) {
      final id = _uid ?? 'guest';
      n = 'Knight${id.substring(0, id.length < 4 ? id.length : 4)}';
    }
    return n.length > 16 ? n.substring(0, 16) : n;
  }

  /// Publishes the player's best Endless score (only ever goes up).
  Future<void> submitScore(PlayerProgress p) async {
    if (p.highestEndlessScore <= 0) return;
    if (!await ensureSignedIn()) return;
    try {
      await FirebaseFirestore.instance.collection('leaderboard').doc(_uid).set({
        'name': displayNameFor(p),
        'score': p.highestEndlessScore,
        'wave': p.highestEndlessWave,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  /// Top players. Returns null when offline / not configured (the screen then
  /// shows a friendly message instead of the list).
  Future<List<LeaderEntry>?> fetchTop({int limit = 20}) async {
    if (!await ensureSignedIn()) return null;
    try {
      final q = await FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('score', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      return q.docs.map((d) {
        final m = d.data();
        return LeaderEntry(
          uid: d.id,
          name: (m['name'] ?? 'Knight').toString(),
          score: (m['score'] as num?)?.toInt() ?? 0,
          wave: (m['wave'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
