// The actual battle view: Flame's GameWidget rendering the battlefield,
// with BattleHud pinned to the top, BottomTowerBar pinned to the bottom, a
// tap layer for placing the currently-armed tower on a grid slot, and
// Victory/DefeatOverlay shown once BattleEngine's status leaves "ongoing".
// Assumes StateProvider already has an active battle (started by whichever
// screen navigated here via startCampaignLevel()/startEndless()).
import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/game_balance.dart';
import '../game_logic/army_manager.dart';
import '../game_logic/battle_engine.dart';
import '../game_logic/path_manager.dart';
import '../game_logic/state_provider.dart';
import '../game/kingdom_wars_game.dart';
import '../models/tower.dart';
import '../services/sound_service.dart';
import '../services/orientation_service.dart';
import '../widgets/battle_hud.dart';
import '../widgets/bottom_tower_bar.dart';
import '../widgets/defeat_overlay.dart';
import '../widgets/pause_menu_overlay.dart';
import '../widgets/troop_bar.dart';
import '../widgets/victory_overlay.dart';
import 'town_screen.dart';

enum _BottomMode { troops, towers }

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late KingdomWarsGame _game;
  int _gameGen = 0;
  TowerType? _selectedTowerType;
  _BottomMode _bottomMode = _BottomMode.troops;
  bool _showPauseMenu = false;
  String? _selectedUnitKey; // soldier picked up for rearranging (formation key)

  @override
  void initState() {
    super.initState();
    final provider = context.read<StateProvider>();
    _game = KingdomWarsGame(provider: provider);
    OrientationService.instance.enterLandscape();
    SoundService.instance.playBattleMusic();
  }

  @override
  void dispose() {
    SoundService.instance.battleEnded(); // no battle cries / old sfx after leaving
    OrientationService.instance.leaveLandscape();
    super.dispose();
  }

  void _onGridTap(TapDownDetails details, StateProvider provider) {
    if (_selectedTowerType == null) {
      _onFormationTap(details.localPosition.dx, details.localPosition.dy, provider);
      return;
    }
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    // Cell size scales with the battlefield's current zoom (pixelsPerUnit),
    // same as the grid overlay drawn in PathComponent, so tap hit-testing
    // still lines up with the visible squares on any screen size.
    final cellSize = GameBalance.towerGridCellSize * (_game.pixelsPerUnit / 48.0);
    for (int col = 0; col < GameBalance.towerGridColumns; col++) {
      for (int row = 0; row < GameBalance.towerGridRows; row++) {
        final (worldX, worldY) = PathManager.towerSlotPosition(col, row);
        final screenPos = _game.worldToScreen(worldX, worldY);
        final half = cellSize / 2;
        if ((tapX - screenPos.x).abs() <= half && (tapY - screenPos.y).abs() <= half) {
          final placed = provider.buildTower(_selectedTowerType!, col, row);
          if (placed) {
            SoundService.instance.playVfx();
            setState(() => _selectedTowerType = null);
          }
          return;
        }
      }
    }
  }

  /// Rearranging soldiers right on the battlefield:
  ///  1) tap a soldier to pick him up,
  ///  2) tap another soldier to swap places with him, or tap an empty square
  ///     to move there (front, back, behind the archers... anywhere).
  /// Tap the same soldier again (or empty ground) to cancel.
  void _onFormationTap(double tapX, double tapY, StateProvider provider) {
    final battle = provider.gameEngine.activeBattle;
    if (battle == null || battle.status != BattleStatus.ongoing || _showPauseMenu) return;
    final ppu = _game.pixelsPerUnit;

    // 1) Which living soldier (if any) was tapped? (sprites stand a bit above
    //    their ground point, so aim a little higher.)
    String? tappedKey;
    var bestD = ppu * 0.7;
    for (final u in battle.units) {
      if (!u.alive || u.formationKey.isEmpty) continue;
      final pos = _game.worldToScreen(u.x, u.y);
      final dx = tapX - pos.x;
      final dy = tapY - (pos.y - ppu * 0.25);
      final d = _len(dx, dy);
      if (d < bestD) {
        bestD = d;
        tappedKey = u.formationKey;
      }
    }

    final sel = _selectedUnitKey;
    if (tappedKey != null) {
      if (sel == null) {
        SoundService.instance.playButtonTap();
        setState(() => _selectedUnitKey = tappedKey);
      } else if (sel == tappedKey) {
        setState(() => _selectedUnitKey = null);
      } else {
        // Swap with the tapped soldier: move "sel" into his cell (the engine
        // swaps the two automatically).
        for (final slot in provider.currentFormationSlots()) {
          if (slot.key == tappedKey) {
            if (provider.moveFormationUnit(sel, slot.col, slot.row)) SoundService.instance.playButtonTap();
            break;
          }
        }
        setState(() => _selectedUnitKey = null);
      }
      return;
    }
    if (sel == null) return;

    // 2) A soldier is picked up and the tap hit empty ground: nearest square.
    int? bestCol, bestRow;
    var cellD = ppu * 0.5;
    for (var c = 0; c < ArmyManager.gridCols; c++) {
      for (var r = 0; r < ArmyManager.gridRows; r++) {
        final pos = _game.worldToScreen(ArmyManager.cellX(c), ArmyManager.cellY(r));
        final d = _len(tapX - pos.x, tapY - pos.y);
        if (d < cellD) {
          cellD = d;
          bestCol = c;
          bestRow = r;
        }
      }
    }
    if (bestCol != null && bestRow != null) {
      if (provider.moveFormationUnit(sel, bestCol, bestRow)) SoundService.instance.playButtonTap();
    }
    setState(() => _selectedUnitKey = null);
  }

  double _len(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

  void _exitToHome() {
    context.read<StateProvider>().exitBattle();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Leaves the battle and opens the Town so the player can spend the new coins / diamonds.
  void _openTown() {
    final nav = Navigator.of(context);
    context.read<StateProvider>().exitBattle();
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => const TownScreen()));
  }

  void _retry() {
    final provider = context.read<StateProvider>();
    final battle = provider.gameEngine.activeBattle;
    if (battle?.level != null) {
      provider.startCampaignLevel(battle!.level!.id);
    } else {
      provider.startEndless();
    }
    setState(() {
      _game = KingdomWarsGame(provider: provider);
      _gameGen++;
      _selectedUnitKey = null;
    });
  }

  void _openPauseMenu(StateProvider provider) {
    SoundService.instance.playButtonTap();
    provider.pauseBattle();
    setState(() => _showPauseMenu = true);
  }

  void _onResumedFromMenu() {
    setState(() => _showPauseMenu = false);
    context.read<StateProvider>().resumeBattle();
  }

  void _nextLevel() {
    final provider = context.read<StateProvider>();
    final currentLevelId = provider.gameEngine.activeBattle?.level?.id ?? 0;
    provider.startCampaignLevel(currentLevelId + 1);
    setState(() {
      _game = KingdomWarsGame(provider: provider);
      _gameGen++;
      _selectedUnitKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<StateProvider>(
        builder: (context, provider, _) {
          final battle = provider.gameEngine.activeBattle;
          if (battle == null) {
            return const Center(child: Text('No active battle.'));
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: (details) => _onGridTap(details, provider),
                  // SizedBox.expand forces the canvas to claim the full
                  // Stack size on every layout pass (including a browser
                  // window resize), rather than potentially keeping
                  // whatever size it first rendered at — that mismatch is
                  // what left a raw black strip down one side.
                  child: SizedBox.expand(child: GameWidget(key: ValueKey(_gameGen), game: _game)),
                ),
              ),
              if (_selectedUnitKey != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _FormationOverlay(game: _game, provider: provider, selectedKey: _selectedUnitKey!),
                  ),
                ),
              const Align(alignment: Alignment.topCenter, child: BattleHud()),
              if (_selectedUnitKey != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 150,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkPurple.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.royalGold),
                        ),
                        child: const Text(
                          'Tap another soldier to SWAP, or an empty square to MOVE.  Tap again to cancel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textGold, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              // Hidden while its own pause menu is showing (the menu already
              // has its own way back out via Resume/Home/Quit), so the icon
              // never sits on top of the overlay it opened.
              if (!_showPauseMenu)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: IconButton(
                        onPressed: () {
                          SoundService.instance.playButtonTap();
                          _openPauseMenu(provider);
                        },
                        icon: const Icon(Icons.menu, color: AppColors.royalGold, size: 28),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeSwitch(
                      mode: _bottomMode,
                      onChanged: (mode) => setState(() => _bottomMode = mode),
                    ),
                    if (_bottomMode == _BottomMode.troops)
                      const TroopBar()
                    else
                      BottomTowerBar(
                        selectedType: _selectedTowerType,
                        onSelect: (type) => setState(() => _selectedTowerType = type),
                      ),
                  ],
                ),
              ),
              if (battle.status == BattleStatus.victory)
                VictoryOverlay(
                  result: provider.gameEngine.lastResult!,
                  isEndless: battle.isEndless,
                  onHome: _exitToHome,
                  onNextLevel: battle.level != null ? _nextLevel : null,
                  onTown: _openTown,
                ),
              if (battle.status == BattleStatus.defeat)
                DefeatOverlay(
                  onHome: _exitToHome,
                  onRetry: _retry,
                  byMp: battle.defeatedByMp,
                  endlessScore: battle.isEndless ? provider.lastEndlessScore : null,
                  endlessWave: provider.lastEndlessWave,
                  endlessKills: provider.lastEndlessKills,
                  newBest: provider.lastEndlessNewBest,
                  bestScore: provider.progress.highestEndlessScore,
                ),
              if (_showPauseMenu)
                PauseMenuOverlay(onResumed: _onResumedFromMenu, onExit: _exitToHome),
            ],
          );
        },
      ),
    );
  }
}

/// Small pill toggle sitting right above the bottom bar so the player can
/// flip between deploying troops (default, matches the always-tappable
/// character row) and placing towers on the castle-wall grid.
class _ModeSwitch extends StatelessWidget {
  final _BottomMode mode;
  final ValueChanged<_BottomMode> onChanged;

  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.darkPurple.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('Troops', _BottomMode.troops),
          _tab('Towers', _BottomMode.towers),
        ],
      ),
    );
  }

  Widget _tab(String label, _BottomMode value) {
    final selected = mode == value;
    return GestureDetector(
      onTap: () {
        SoundService.instance.playButtonTap();
        onChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalGold.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.royalGold : AppColors.textPrimary.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// While a soldier is picked up: shows the 5x5 formation squares on the
/// battlefield and rings the picked soldier's square. Repaints ~10x/second
/// because the battle ticks without notifying listeners.
class _FormationOverlay extends StatefulWidget {
  final KingdomWarsGame game;
  final StateProvider provider;
  final String selectedKey;

  const _FormationOverlay({required this.game, required this.provider, required this.selectedKey});

  @override
  State<_FormationOverlay> createState() => _FormationOverlayState();
}

class _FormationOverlayState extends State<_FormationOverlay> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.provider.currentFormationSlots();
    final occupied = <int, bool>{for (final s in slots) ArmyManager.cellId(s.col, s.row): s.key == widget.selectedKey};
    return CustomPaint(
      painter: _FormationPainter(widget.game, occupied),
      size: Size.infinite,
    );
  }
}

class _FormationPainter extends CustomPainter {
  final KingdomWarsGame game;
  final Map<int, bool> occupied; // cellId -> is the picked-up soldier's square
  _FormationPainter(this.game, this.occupied);

  @override
  void paint(Canvas canvas, Size size) {
    final ppu = game.pixelsPerUnit;
    final half = ppu * 0.36;
    for (var c = 0; c < ArmyManager.gridCols; c++) {
      for (var r = 0; r < ArmyManager.gridRows; r++) {
        final pos = game.worldToScreen(ArmyManager.cellX(c), ArmyManager.cellY(r));
        final rect = Rect.fromCenter(center: Offset(pos.x, pos.y), width: half * 2, height: half * 2);
        final id = ArmyManager.cellId(c, r);
        final isSel = occupied[id] == true;
        final taken = occupied.containsKey(id);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = (isSel ? const Color(0xFFF2CE7C) : (taken ? Colors.white : const Color(0xFF69F0AE))).withValues(alpha: isSel ? 0.28 : 0.12),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 3 : 1.2
            ..color = isSel ? const Color(0xFFF2CE7C) : Colors.white.withValues(alpha: 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FormationPainter old) => true;
}
