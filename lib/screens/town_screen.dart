// TOWN: the player builds a whole, ENDLESS town (streets, houses, public
// buildings, parks, fountains, rivers, bridges, trains, LEGO and greenery).
// Houses are free; everything else is bought with coins or diamonds earned by
// winning campaign levels (new pieces unlock as levels are beaten).
//
// Controls: drag with one finger to look around, pinch (or mouse wheel) to
// zoom. Pick a piece from the shelf and tap the map to place it. Streets,
// rivers, rails, fields and cheap decor can be PAINTED: with such a piece
// selected, drag one finger across the map (use two fingers to move the view).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/town_data.dart';
import '../game_logic/state_provider.dart';
import '../services/sound_service.dart';
import '../town/town_art.dart';
import '../town/town_painter.dart';
import '../widgets/top_hud_bar.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final TownCamera _cam = TownCamera();

  TownCategory _category = TownCategory.houses;
  String? _brush; // building id being placed, null = just looking
  bool _demolish = false;
  bool _shelfOpen = true;
  int? _selectedKey;
  int? _lastDragKey;
  bool _fitted = false;
  Size _viewport = Size.zero;

  // gesture bookkeeping
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1.0;
  int _lastPointers = 0;

  @override
  void initState() {
    super.initState();
    // Runs 0..1 over 1000s; painters multiply by 1000 to get seconds.
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    _cam.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Camera
  // ------------------------------------------------------------------
  /// Looks at the middle of everything built so far (or the start spot).
  void _centreOnTown({bool animateZoom = true}) {
    final grid = context.read<StateProvider>().progress.townGrid;
    final vp = _viewport;
    if (vp.isEmpty) return;
    if (grid.isEmpty) {
      final c = TownLayout.centreOf(TownData.homeCol, TownData.homeRow);
      _cam.set(c.dx, c.dy, 1.0);
      return;
    }
    var minC = 1 << 30, maxC = -(1 << 30), minR = 1 << 30, maxR = -(1 << 30);
    for (final k in grid.keys) {
      final c = TownData.colOf(k), r = TownData.rowOf(k);
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
    }
    final w = (maxC - minC + 1 + 4) * TownLayout.tile;
    final h = (maxR - minR + 1 + 6) * TownLayout.tile;
    final sc = (vp.width / w < vp.height / h ? vp.width / w : vp.height / h).clamp(0.5, 1.0).toDouble();
    final cx = (minC + maxC + 1) / 2 * TownLayout.tile;
    final cy = (minR + maxR + 1) / 2 * TownLayout.tile - TownLayout.tile * 0.4;
    _cam.set(cx, cy, sc);
  }

  void _toast(String msg, {bool good = false}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1400),
      behavior: SnackBarBehavior.floating,
      backgroundColor: good ? AppColors.emeraldGood : AppColors.buttonPrimary,
      margin: const EdgeInsets.fromLTRB(80, 0, 80, 12),
    ));
  }

  // ------------------------------------------------------------------
  // Map interaction
  // ------------------------------------------------------------------
  String _refundText(BuildingDef def) {
    final c = TownData.refundCoins(def);
    final d = TownData.refundDiamonds(def);
    final parts = <String>[];
    if (c > 0) parts.add('+$c coins');
    if (d > 0) parts.add('+$d diamonds');
    return parts.isEmpty ? '' : '  (${parts.join(', ')})';
  }

  void _handleCell(int col, int row, {bool fromDrag = false}) {
    final provider = context.read<StateProvider>();
    final key = TownData.key(col, row);
    setState(() => _selectedKey = key);

    if (_demolish) {
      final had = provider.progress.townGrid[key];
      final err = provider.demolish(col, row);
      if (err != null) {
        if (!fromDrag) _toast(err);
      } else {
        SoundService.instance.playButtonTap();
        final def = TownData.byId(had ?? '');
        if (def != null && !fromDrag) {
          _toast('${def.name} removed${_refundText(def)}', good: true);
        }
      }
      return;
    }

    final brush = _brush;
    if (brush != null) {
      final err = provider.placeBuilding(brush, col, row);
      if (err != null) {
        // While dragging, silently skip occupied tiles; show real problems.
        if (!(fromDrag && err.startsWith('This spot'))) _toast(err);
      } else {
        SoundService.instance.playButtonTap();
        _showLevelUpIfAny(provider);
      }
      return;
    }

    // Looking mode: tap a building to see info.
    final id = provider.progress.townGrid[key];
    if (id != null) _showInfo(id, col, row);
  }

  void _onTapUp(TapUpDetails d) {
    final cell = TownLayout.cellAt(_cam.screenToWorld(d.localPosition, _viewport));
    if (cell == null) return;
    _handleCell(cell.col, cell.row);
  }

  bool get _dragPaints {
    if (_demolish) return true;
    final b = _brush == null ? null : TownData.byId(_brush!);
    return b != null && b.dragPlaceable;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocal = d.localFocalPoint;
    _lastScale = 1.0;
    _lastPointers = d.pointerCount;
    _lastDragKey = null;
    if (d.pointerCount == 1 && _dragPaints) _paintAt(d.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // When a finger is added or lifted the numbers jump: just re-base.
    if (d.pointerCount != _lastPointers) {
      _lastPointers = d.pointerCount;
      _lastFocal = d.localFocalPoint;
      _lastScale = d.scale;
      return;
    }
    if (d.pointerCount >= 2) {
      final delta = d.localFocalPoint - _lastFocal;
      _cam.panBy(delta.dx, delta.dy);
      if (_lastScale > 0 && d.scale != _lastScale) {
        _cam.zoomAt(d.scale / _lastScale, d.localFocalPoint, _viewport);
      }
    } else if (_dragPaints) {
      _paintAt(d.localFocalPoint);
    } else {
      final delta = d.localFocalPoint - _lastFocal;
      _cam.panBy(delta.dx, delta.dy);
    }
    _lastFocal = d.localFocalPoint;
    _lastScale = d.scale;
  }

  void _paintAt(Offset screen) {
    final cell = TownLayout.cellAt(_cam.screenToWorld(screen, _viewport));
    if (cell == null) return;
    final key = TownData.key(cell.col, cell.row);
    if (key == _lastDragKey) return;
    _lastDragKey = key;
    _handleCell(cell.col, cell.row, fromDrag: true);
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = e.scrollDelta.dy > 0 ? 0.9 : 1.1;
      _cam.zoomAt(factor, e.localPosition, _viewport);
    }
  }

  // ------------------------------------------------------------------
  // Dialogs
  // ------------------------------------------------------------------
  void _showLevelUpIfAny(StateProvider provider) {
    final d = provider.pendingTownRewardDiamonds;
    if (d <= 0) return;
    provider.pendingTownRewardDiamonds = 0;
    final name = TownData.levelNames[provider.townLevel.clamp(0, TownData.levelNames.length - 1)];
    SoundService.instance.playVfx();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.royalGold, width: 2),
        ),
        title: Row(children: const [
          Icon(Icons.emoji_events, color: AppColors.royalGold),
          SizedBox(width: 8),
          Text('TOWN LEVEL UP!'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Your town is now a $name!', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.diamond, color: AppColors.diamondBlue),
            const SizedBox(width: 6),
            Text('+$d', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.pop(ctx);
            },
            child: const Text('NICE!'),
          ),
        ],
      ),
    );
  }

  void _showInfo(String id, int col, int row) {
    final def = TownData.byId(id);
    if (def == null) return;
    final refund = _refundText(def).replaceAll('(', '').replaceAll(')', '').trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.royalGold.withOpacity(0.6), width: 1.5),
        ),
        title: Text(def.name),
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          BuildingPreview(id: id, size: 64, time: _clock),
          const SizedBox(width: 16),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.blurb, style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (def.population > 0) _statLine(Icons.people, '+${def.population} citizens'),
              if (def.happiness > 0) _statLine(Icons.favorite, '+${def.happiness} happiness'),
              if (def.population == 0 && def.happiness == 0) _statLine(Icons.info_outline, 'Just for looks'),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.pop(ctx);
              final p = context.read<StateProvider>();
              p.demolish(col, row);
              _toast('${def.name} removed${_refundText(def)}', good: true);
            },
            child: Text(refund.isEmpty ? 'DEMOLISH' : 'DEMOLISH  $refund', style: const TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.pop(ctx);
            },
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _statLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.lightGold),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppColors.textPrimary)),
        ]),
      );

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StateProvider>();
    final progress = provider.progress;

    return Scaffold(
      backgroundColor: const Color(0xFF6DBB4E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(provider),
            Expanded(child: _buildMap(progress.townGrid)),
            _buildShelf(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(StateProvider provider) {
    final progress = provider.progress;
    final lvl = provider.townLevel;
    final score = provider.townScore;
    final nextAt = lvl + 1 < TownData.levelThresholds.length ? TownData.levelThresholds[lvl + 1] : null;
    final curAt = TownData.levelThresholds[lvl];
    final frac = nextAt == null ? 1.0 : ((score - curAt) / (nextAt - curAt)).clamp(0.0, 1.0);

    return Container(
      color: AppColors.darkPurple,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back, color: AppColors.lightGold),
            onPressed: () {
              SoundService.instance.playButtonTap();
              Navigator.of(context).maybePop();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Town title + level progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MY TOWN • ${TownData.levelNames[lvl]}',
                        style: const TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        width: 130,
                        height: 7,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(AppColors.emeraldGood),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  HudChip(icon: Icons.monetization_on, color: AppColors.royalGold, value: '${progress.coins}'),
                  const SizedBox(width: 6),
                  HudChip(icon: Icons.diamond, color: AppColors.diamondBlue, value: '${progress.diamonds}'),
                  const SizedBox(width: 6),
                  HudChip(icon: Icons.people, color: AppColors.lightGold, value: '${provider.townPopulation}'),
                  const SizedBox(width: 6),
                  HudChip(icon: Icons.favorite, color: Colors.pinkAccent, value: '${provider.townHappiness}'),
                ],
              ),
            ),
          ),
          _TopAction(
            icon: Icons.my_location,
            tooltip: 'Go to my town',
            onTap: _centreOnTown,
          ),
          _TopAction(
            icon: Icons.delete_outline,
            tooltip: 'Demolish',
            active: _demolish,
            activeColor: Colors.redAccent,
            onTap: () => setState(() {
              _demolish = !_demolish;
              if (_demolish) _brush = null;
              _selectedKey = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(Map<int, String> grid) {
    return LayoutBuilder(builder: (context, box) {
      final vp = Size(box.maxWidth, box.maxHeight);
      _viewport = vp;
      if (!_fitted && !vp.isEmpty) {
        _fitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _centreOnTown();
        });
      }
      return Stack(
        children: [
          ClipRect(
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onTapUp,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: TownPainter(
                      grid: grid,
                      time: _clock,
                      camera: _cam,
                      selectedKey: _selectedKey,
                      showGrid: _brush != null || _demolish,
                      demolishMode: _demolish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Hint banner
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: IgnorePointer(child: Center(child: _hintBanner(grid))),
          ),
        ],
      );
    });
  }

  Widget _hintBanner(Map<int, String> grid) {
    String? text;
    if (_demolish) {
      text = 'DEMOLISH MODE — tap or drag over buildings to remove them';
    } else if (_brush != null) {
      final def = TownData.byId(_brush!);
      if (def != null && def.placeOn.isNotEmpty) {
        final names = def.placeOn.map((id) => TownData.byId(id)?.name ?? id).join(' / ');
        text = 'Placing ${def.name} — tap a $names tile';
      } else if (def != null && def.dragPlaceable) {
        text = 'Placing ${def.name} — drag to paint • two fingers to move';
      } else {
        text = 'Placing ${def?.name ?? ''} — tap an empty spot';
      }
    } else if (grid.isEmpty) {
      text = 'Pick something from the shelf below to start building! Houses are free.';
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _demolish ? Colors.redAccent : AppColors.royalGold.withOpacity(0.6)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildShelf(StateProvider provider) {
    final progress = provider.progress;
    final defs = TownData.inCategory(_category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkPurple,
        border: Border(top: BorderSide(color: AppColors.royalGold.withOpacity(0.5), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category tabs + collapse
          SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    children: [
                      for (final c in TownCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(c.icon, size: 16, color: _category == c ? Colors.black : AppColors.lightGold),
                            label: Text(c.label, style: TextStyle(fontSize: 12, color: _category == c ? Colors.black : Colors.white)),
                            selected: _category == c,
                            selectedColor: AppColors.royalGold,
                            backgroundColor: AppColors.deepPurple,
                            onSelected: (_) {
                              SoundService.instance.playButtonTap();
                              setState(() {
                                _category = c;
                                _shelfOpen = true;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_brush != null)
                  TextButton.icon(
                    onPressed: () {
                      SoundService.instance.playButtonTap();
                      setState(() => _brush = null);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Done', style: TextStyle(fontSize: 12)),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_shelfOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.lightGold),
                  onPressed: () {
                    SoundService.instance.playButtonTap();
                    setState(() => _shelfOpen = !_shelfOpen);
                  },
                ),
              ],
            ),
          ),
          if (_shelfOpen)
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                itemCount: defs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final def = defs[i];
                  final unlocked = provider.isBuildingUnlocked(def);
                  final affordable = progress.coins >= def.coins && progress.diamonds >= def.diamonds;
                  return _BuildCard(
                    def: def,
                    unlocked: unlocked,
                    affordable: affordable,
                    selected: _brush == def.id,
                    clock: _clock,
                    onTap: () {
                      if (!unlocked) {
                        _toast('Win ${def.unlockWins} campaign level${def.unlockWins == 1 ? '' : 's'} to unlock ${def.name}');
                        return;
                      }
                      SoundService.instance.playButtonTap();
                      setState(() {
                        _brush = _brush == def.id ? null : def.id;
                        _demolish = false;
                        _selectedKey = null;
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.royalGold,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: active ? activeColor : AppColors.lightGold),
      style: active ? IconButton.styleFrom(backgroundColor: activeColor.withOpacity(0.2)) : null,
      onPressed: () {
        SoundService.instance.playButtonTap();
        onTap();
      },
    );
  }
}

class _BuildCard extends StatelessWidget {
  final BuildingDef def;
  final bool unlocked;
  final bool affordable;
  final bool selected;
  final Animation<double> clock;
  final VoidCallback onTap;

  const _BuildCard({
    required this.def,
    required this.unlocked,
    required this.affordable,
    required this.selected,
    required this.clock,
    required this.onTap,
  });

  Widget _price() {
    if (def.isFree) {
      return const Text('FREE', style: TextStyle(color: AppColors.emeraldGood, fontSize: 12, fontWeight: FontWeight.bold));
    }
    final color = affordable ? AppColors.lightGold : Colors.redAccent;
    final icon = def.usesDiamonds
        ? const Icon(Icons.diamond, size: 13, color: AppColors.diamondBlue)
        : const Icon(Icons.monetization_on, size: 13, color: AppColors.royalGold);
    final value = def.usesDiamonds ? def.diamonds : def.coins;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      icon,
      const SizedBox(width: 3),
      Text('$value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.deepPurple,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.royalGold : AppColors.royalGold.withOpacity(0.25),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: AppColors.royalGold.withOpacity(0.4), blurRadius: 8)] : null,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: unlocked ? 1 : 0.35,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      child: BuildingPreview(id: def.id, size: 56, time: clock),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(def.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                if (unlocked)
                  _price()
                else
                  Text('Win ${def.unlockWins} lvl', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
            if (!unlocked)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(Icons.lock, size: 16, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}
