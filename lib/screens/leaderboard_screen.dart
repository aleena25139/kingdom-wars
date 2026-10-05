// Rankings screen. Top part = the player's own local records (always work,
// online or offline). Bottom part = GLOBAL top 20 from Firebase: shown when
// the phone is online and Firebase is set up, otherwise a friendly "offline"
// note with a Refresh button. The game never needs the internet.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/level_data.dart';
import '../game_logic/state_provider.dart';
import '../services/firebase_service.dart';
import '../services/sound_service.dart';
import '../widgets/top_hud_bar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  List<LeaderEntry>? _top; // null = offline / not available

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final top = await FirebaseService.instance.fetchTop();
    if (!mounted) return;
    setState(() {
      _top = top;
      _loading = false;
    });
  }

  Future<void> _editName(StateProvider provider) async {
    SoundService.instance.playButtonTap();
    final controller = TextEditingController(text: provider.progress.playerName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(hintText: 'Name on the leaderboard'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.pop(ctx);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (name == null) return;
    provider.setPlayerName(name);
    // give the new name a moment to reach the server, then reload the list
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final progress = provider.progress;
    final totalStars = progress.starsPerLevel.values.fold<int>(0, (sum, s) => sum + s);
    final maxStars = LevelData.totalUnlockedLevelsCount(progress.unlockedLevelIds) * 3;
    final myUid = FirebaseService.instance.uid;
    final myName = FirebaseService.instance.displayNameFor(progress);

    return Scaffold(
      appBar: AppBar(title: const Text('🏆 LEADERBOARD')),
      body: Column(
        children: [
          const TopHudBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 8),
                _RecordCard(
                  icon: Icons.all_inclusive,
                  color: AppColors.diamondBlue,
                  title: 'Best Endless Wave',
                  value: '${progress.highestEndlessWave}',
                ),
                const SizedBox(height: 12),
                _RecordCard(
                  icon: Icons.emoji_events,
                  color: AppColors.lightGold,
                  title: 'Best Endless Score',
                  value: '${progress.highestEndlessScore}',
                ),
                const SizedBox(height: 12),
                _RecordCard(
                  icon: Icons.star,
                  color: AppColors.royalGold,
                  title: 'Campaign Stars',
                  value: '$totalStars / $maxStars',
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.public, color: AppColors.cyan),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('GLOBAL TOP 20',
                            style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () => _editName(provider),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(myName, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh, color: AppColors.lightGold),
                        onPressed: _loading
                            ? null
                            : () {
                                SoundService.instance.playButtonTap();
                                _refresh();
                              },
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.royalGold)),
                  )
                else if (_top == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Column(
                      children: [
                        Icon(Icons.public_off, color: AppColors.cyan, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'You are offline (or online features are not set up yet).\n'
                          'The game works fine without internet. Connect and tap refresh to see the world ranking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.cyan, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else if (_top!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No scores yet - play Endless and be the first!',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  )
                else
                  for (var i = 0; i < _top!.length; i++) _rankRow(i, _top![i], _top![i].uid == myUid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankRow(int i, LeaderEntry e, bool me) {
    final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '#${i + 1}'));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: me ? AppColors.royalGold.withOpacity(0.18) : AppColors.deepPurple,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: me ? AppColors.royalGold : AppColors.royalGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(width: 38, child: Text(medal, style: const TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold))),
          Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary))),
          Text('Wave ${e.wave}', style: TextStyle(color: AppColors.textPrimary.withOpacity(0.6), fontSize: 11)),
          const SizedBox(width: 12),
          Text('${e.score}', style: const TextStyle(color: AppColors.lightGold, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _RecordCard({required this.icon, required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
