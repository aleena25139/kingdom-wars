// Renders a single player unit. Every frame it just copies Unit.x/Unit.y
// (converted to screen space) into its own position and updates the health
// bar from Unit.hp — BattleEngine owns all movement/combat math.
//
// Art fallback chain, checked once in onLoad():
//   1. "<name>_walk.png" + "<name>_attack.png" sheets present → real
//      SpriteAnimation, switches to the attack cycle the instant the model
//      lands a hit (attackCooldown resets), back to walk when it finishes.
//   2. Only the static "<name>.png" present → single image, with a quick
//      lunge + white flash standing in for the attack (see _lungeTimer).
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/unit_data.dart';
import '../../models/unit.dart';
import '../../services/creature_painter.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';
import 'health_bar_component.dart';
import 'shadow_helper.dart';
import 'sprite_anim_helper.dart';

class UnitComponent extends PositionComponent {
  final Unit unit;
  final KingdomWarsGame game;

  late final HealthBarComponent _healthBar;
  SpriteComponent? _staticSprite;
  SpriteAnimationComponent? _walkAnim;
  SpriteAnimationComponent? _attackAnim;

  // Procedural fallback (no PNG shipped for this unit -> draw it in code).
  CreatureKind? _procKind;
  Color? _fallbackTint; // colour wash when a stand-in sprite is used
  double _procWalk = 0;
  double _procAttackElapsed = 999;
  double _procPrevX = 0;

  double _prevAttackCooldown = 0;
  double _hoverTime = 0;
  double _lungeTimer = 0;
  double _attackAnimTimer = 0;
  static const double _lungeDuration = 0.15;
  static const double _lungeDistance = 6.0; // px, toward the enemy castle

  // Knight-only "sword light" hit flash: a short glowing burst at the sword
  // tip the instant a hit lands, standing in for the Knight's blade
  // "destroying" the enemy with light. Uses the 'sword_light' sprite
  // (services/sprite_registry.dart) if that art has been added; otherwise
  // falls back to a procedurally-drawn glow + slash streak so the effect
  // works immediately even before custom art exists.
  double _lightFlashTimer = 0;
  static const double _lightFlashDuration = 0.24;

  // Knight lightning strike: a jagged bolt from the sword tip to the enemy
  // that was just hit (the Knight hits from a distance, see
  // UnitDef.usesLightning). Target is stored in screen space at strike time.
  double _boltTimer = 0;
  static const double _boltDuration = 0.28;
  Vector2? _boltTargetScreen;
  int _boltSeed = 0;

  // Panda Warrior kung-fu: on every hit the Panda himself launches one of
  // three moves, cycling with Unit.comboCount — 0 flying kick, 1 palm-strike
  // flurry, 2 spin kick (the one that also sweeps nearby enemies). The body
  // sprite is thrown toward the struck enemy with afterimages, a swoosh and
  // an impact burst on the target.
  double _kfTimer = 0;
  int _kfMove = 0;
  static const double _kfDuration = 0.55;
  Vector2? _kfTargetScreen;
  static const String _pandaFile = 'kenney/units/panda_warrior.png';

  // Kung-fu stance: gentle breathing bob when idle, bouncy steps when moving,
  // red flash when hurt.
  double _stanceTime = 0;
  double _walkBob = 0;
  double _kfPrevX = 0;
  double _kfPrevY = 0;
  int _prevHp = 0;
  double _hurtTimer = 0;

  // Archers are a small, tightly-packed defensive squad — much smaller than
  // the old mixed-unit army so ~20 of them fit comfortably next to the
  // castle without overlapping.
  // (Per-type sizes now live in UnitData.renderSizeFor — Dragon and Phoenix
  // are drawn much bigger than the 30px soldiers.)

  // Dragon + Phoenix: big sprites that turn around to face their target.
  bool get _isBigFlyer => unit.type == UnitType.dragon || unit.type == UnitType.phoenix;

  // -1..1 horizontal mirror of the sprite. 1 = facing right (art default),
  // -1 = facing left. It glides between the two so the creature visibly
  // swings around (passing edge-on in the middle) instead of snapping.
  double _faceScale = 1.0;
  double _turnHop = 0;
  static const double _turnSpeed = 7.5; // full flip in ~0.27s

  UnitComponent({required this.unit, required this.game})
      : super(
          size: Vector2.all(UnitData.renderSizeFor(unit.type, kungFu: unit.usesKungFu)),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    position = game.worldToScreen(unit.x, unit.y);
    _healthBar = HealthBarComponent(
      size: _isBigFlyer ? Vector2(52, 12) : Vector2(30, 10),
      position: Vector2(size.x / 2, _isBigFlyer ? -10 : -8),
      showsHpText: true,
    );
    add(_healthBar);

    final basePath = SpriteRegistry.pathFor(unit.spriteName);
    final walkAnimation = await SpriteAnimHelper.tryLoad(game, basePath, 'walk', stepTime: 0.12);
    final attackAnimation =
        await SpriteAnimHelper.tryLoad(game, basePath, 'attack', stepTime: 0.08, loop: false);

    if (walkAnimation != null) {
      _walkAnim = SpriteAnimationComponent(animation: walkAnimation, size: size, removeOnFinish: false);
      if (_isBigFlyer) {
        _walkAnim!.anchor = Anchor.center;
        _walkAnim!.position = size / 2;
      }
      add(_walkAnim!);
      if (attackAnimation != null) {
        _attackAnim = SpriteAnimationComponent(
          animation: attackAnimation,
          size: size,
          removeOnFinish: false,
          playing: false,
        );
        _attackAnim!.opacity = 0;
        if (_isBigFlyer) {
          _attackAnim!.anchor = Anchor.center;
          _attackAnim!.position = size / 2;
        }
        add(_attackAnim!);
      }
    } else {
      // No animation sheets yet — fall back to the single static PNG.
      final fileName = basePath.replaceFirst('assets/', '');
      if (game.images.containsKey(fileName)) {
        _staticSprite = SpriteComponent(sprite: Sprite(game.images.fromCache(fileName)), size: size);
        if (unit.usesKungFu || _isBigFlyer) {
          _staticSprite!.anchor = Anchor.center;
          _staticSprite!.position = size / 2;
        }
        add(_staticSprite!);
      } else {
        // Elite units whose own PNG isn't shipped yet borrow an existing
        // unit's art, colour-washed so they still look different.
        final def = UnitData.defFor(unit.type);
        final fb = def.fallbackSprite;
        final fbFile = fb == null ? null : SpriteRegistry.pathFor(fb).replaceFirst('assets/', '');
        if (fbFile != null && game.images.containsKey(fbFile)) {
          _staticSprite = SpriteComponent(sprite: Sprite(game.images.fromCache(fbFile)), size: size);
          if (def.fallbackTint != 0) _fallbackTint = Color(def.fallbackTint);
          if (_isBigFlyer) {
            _staticSprite!.anchor = Anchor.center;
            _staticSprite!.position = size / 2;
          }
          add(_staticSprite!);
        } else {
          _procKind = CreaturePainter.kindFor(fb ?? unit.spriteName);
          _procPrevX = unit.x;
        }
      }
    }
    _prevAttackCooldown = unit.attackCooldown;
    _prevHp = unit.hp;
    _kfPrevX = unit.x;
    _kfPrevY = unit.y;
  }

  @override
  void render(Canvas canvas) {
    drawGroundShadow(canvas, game, size);
    if (_procKind != null) {
      CreaturePainter.paint(
        canvas,
        Size(size.x, size.y),
        _procKind!,
        walk: _procWalk,
        attack: _procAttackElapsed < 0.35 ? _procAttackElapsed / 0.35 : 0,
        facingLeft: _faceScale < 0,
      );
    }
    final boosted = game.provider.gameEngine.activeBattle?.isBoosted(unit.type) ?? false;
    if (boosted) {
      final pulse = 0.55 + 0.25 * math.sin(DateTime.now().millisecondsSinceEpoch / 1000.0 * 12);
      final r = math.max(size.x, size.y) * 0.62;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        r,
        Paint()
          ..color = const Color(0xFF42A5F5).withOpacity(pulse * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        r * 0.8,
        Paint()
          ..color = const Color(0xFF90CAF9).withOpacity(pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (_kfTimer > 0) _renderKungFuAfterimages(canvas);
    super.render(canvas);
    if (_lightFlashTimer > 0) _renderSwordLight(canvas);
    if (_boltTimer > 0 && _boltTargetScreen != null) _renderLightningBolt(canvas);
    if (_kfTimer > 0 && _kfTargetScreen != null) _renderKungFuEffects(canvas);
  }

  /// Pose of the Panda's body at kung-fu progress [t] (0..1): offset in px
  /// from his rest spot, rotation in radians, and a scale pulse.
  ({Offset offset, double angle, double scale}) _kungFuPose(double t) {
    t = t.clamp(0.0, 1.0);
    final target = (_kfTargetScreen ?? position) - position;
    final dist = math.sqrt(target.x * target.x + target.y * target.y);
    final dir = dist < 0.001 ? const Offset(1, 0) : Offset(target.x / dist, target.y / dist);
    final reach = math.min(dist, 11.0); // small lunge only: he never leaves his post
    // Extend hard for the first 40%, then snap back.
    final e = t < 0.4 ? math.sin((t / 0.4) * math.pi / 2) : math.cos(((t - 0.4) / 0.6) * math.pi / 2);
    final arc = math.sin(t * math.pi);
    switch (_kfMove) {
      case 0: // flying kick: leap, lean back, feet-first into the enemy
        return (
          offset: Offset(dir.dx * reach * e, dir.dy * reach * e - 12 * arc),
          angle: -0.6 * e,
          scale: 1.0 + 0.1 * e,
        );
      case 1: // palm-strike flurry: three rapid jabs
        final jab = math.sin(t * math.pi * 3).abs();
        return (
          offset: Offset(dir.dx * reach * 0.55 * jab, dir.dy * reach * 0.55 * jab),
          angle: 0.18 * jab,
          scale: 1.0 + 0.08 * jab,
        );
      default: // spin kick: a full 360 with a hop
        return (
          offset: Offset(dir.dx * reach * 0.6 * e, dir.dy * reach * 0.6 * e - 14 * arc),
          angle: t * math.pi * 2,
          scale: 1.0 + 0.12 * arc,
        );
    }
  }

  /// Fading ghost copies of the Panda trailing behind his current pose.
  void _renderKungFuAfterimages(Canvas canvas) {
    if (!game.images.containsKey(_pandaFile)) return;
    final sprite = Sprite(game.images.fromCache(_pandaFile));
    final t = 1 - (_kfTimer / _kfDuration);
    for (var i = 3; i >= 1; i--) {
      final pose = _kungFuPose(t - i * 0.05);
      canvas.save();
      canvas.translate(size.x / 2 + pose.offset.dx, size.y / 2 + pose.offset.dy);
      canvas.rotate(pose.angle);
      canvas.scale(pose.scale);
      sprite.render(
        canvas,
        position: Vector2(-size.x / 2, -size.y / 2),
        size: size,
        overridePaint: Paint()..color = Colors.white.withOpacity(0.22 - i * 0.05),
      );
      canvas.restore();
    }
  }

  /// Move-specific swoosh plus the impact burst on the struck enemy.
  void _renderKungFuEffects(Canvas canvas) {
    final t = 1 - (_kfTimer / _kfDuration);
    final pose = _kungFuPose(t);
    final body = Offset(size.x / 2 + pose.offset.dx, size.y / 2 + pose.offset.dy);
    final target = _kfTargetScreen! - position + Vector2(size.x / 2, size.y / 2);
    final hit = Offset(target.x, target.y);

    // Swoosh trail.
    final swoosh = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.75 * (1 - t))
      ..strokeWidth = 3;
    if (_kfMove == 2) {
      canvas.drawArc(Rect.fromCircle(center: body, radius: size.x * 0.75), t * math.pi * 2, math.pi * 1.3, false, swoosh);
    } else if (_kfMove == 0) {
      canvas.drawArc(
        Rect.fromCircle(center: body.translate(-4, 2), radius: size.x * 0.7),
        math.pi * 0.85,
        math.pi * 0.7,
        false,
        swoosh,
      );
    } else {
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(body.translate(-6, i * 6.0), body.translate(-18 - 6 * (1 - t), i * 6.0), swoosh);
      }
    }

    // The limb doing the hitting, drawn as a big black fur paw / foot with a
    // white rim so it reads against any ground.
    void limb(Offset from, Offset to, double reachT, double radius, {bool foot = false}) {
      final pos = Offset.lerp(from, to, reachT.clamp(0.0, 1.0))!;
      final rim = Paint()..color = Colors.white.withOpacity(0.9);
      final fur = Paint()..color = const Color(0xFF15151A);
      final arm = Paint()
        ..color = const Color(0xFF15151A)
        ..strokeWidth = radius * 1.15
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, pos, arm);
      if (foot) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(-0.5);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 3.0, height: radius * 1.9), rim);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 2.7, height: radius * 1.6), fur);
        canvas.restore();
      } else {
        canvas.drawCircle(pos, radius * 1.15, rim);
        canvas.drawCircle(pos, radius, fur);
      }
    }

    if (_kfMove == 1) {
      // Palm flurry: three jabs, alternating paws, each with speed lines.
      final jab = (t * 3).floor().clamp(0, 2);
      final local = (t * 3) - jab;
      final reachT = math.sin(local * math.pi);
      final from = Offset(size.x * 0.7, size.y * (jab.isEven ? 0.5 : 0.62));
      limb(from, hit.translate(-4, jab.isEven ? -2 : 3), reachT, 4.6);
      if (reachT > 0.5) {
        final l = Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(from.translate(4, i * 3.0), from.translate(-10, i * 3.0), l);
        }
      }
    } else if (_kfMove == 0) {
      // Flying kick: leg thrust out from the hip, foot lands on the enemy.
      final reachT = t < 0.45 ? math.sin((t / 0.45) * math.pi / 2) : 1 - ((t - 0.45) / 0.55);
      limb(Offset(size.x * 0.6, size.y * 0.78), hit.translate(-3, 2), reachT * 0.9, 5.2, foot: true);
    } else {
      // Spin kick: a foot on each side of the whirling body.
      final ang = t * math.pi * 4;
      final r = size.x * 0.55;
      final c = body;
      limb(c, c + Offset(math.cos(ang), math.sin(ang) * 0.6) * r, 1, 4.6, foot: true);
      limb(c, c - Offset(math.cos(ang), math.sin(ang) * 0.6) * r, 1, 4.6, foot: true);
    }

    // Impact burst at the peak of the strike.
    if (t > 0.25 && t < 0.85) {
      final p = ((t - 0.25) / 0.6).clamp(0.0, 1.0);
      final fade = 1 - p;
      final r = 6 + 16 * p;
      canvas.drawCircle(
        hit,
        r,
        Paint()
          ..color = const Color(0xFFFFE082).withOpacity(0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final star = Paint()
        ..color = Colors.white.withOpacity(0.95 * fade)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + (_kfMove == 2 ? p : 0);
        canvas.drawLine(
          hit + Offset(math.cos(a), math.sin(a)) * (r * 0.5),
          hit + Offset(math.cos(a), math.sin(a)) * (r * 1.25),
          star,
        );
      }
      if (_kfMove == 2) {
        canvas.drawCircle(
          hit,
          r * 1.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(0.6 * fade),
        );
      }
    }
  }

  /// Draws a jagged lightning bolt from the Knight's sword tip to the struck
  /// enemy, with a bright impact burst on the enemy.
  void _renderLightningBolt(Canvas canvas) {
    final fade = (_boltTimer / _boltDuration).clamp(0.0, 1.0);
    final start = Offset(size.x * 0.86, size.y * 0.32);
    final target = _boltTargetScreen! - position + Vector2(size.x / 2, size.y / 2);
    final end = Offset(target.x, target.y);

    final rng = math.Random(_boltSeed);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return;
    final nx = -dy / length; // unit normal for the zig-zag offsets
    final ny = dx / length;
    const segments = 7;
    final path = Path()..moveTo(start.dx, start.dy);
    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final jitter = (rng.nextDouble() - 0.5) * 16;
      path.lineTo(start.dx + dx * t + nx * jitter, start.dy + dy * t + ny * jitter);
    }
    path.lineTo(end.dx, end.dy);

    // Wide soft glow, then a thin white-hot core.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7FD4FF).withOpacity(0.55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.95 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      end,
      10 * (1.3 - 0.5 * fade),
      Paint()
        ..color = const Color(0xFFBFEAFF).withOpacity(0.8 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  /// Draws the Knight's sword-light hit flash at [_lightFlashTimer]'s
  /// current progress. Positioned toward the unit's front-upper area (where
  /// a raised sword would be) and toward the enemy castle side, since every
  /// player unit always faces +x (see PathManager.playerDirection).
  void _renderSwordLight(Canvas canvas) {
    final progress = 1 - (_lightFlashTimer / _lightFlashDuration); // 0 -> 1 over the flash
    final fade = (1 - progress).clamp(0.0, 1.0);
    final centerX = size.x * 0.86;
    final centerY = size.y * 0.32;

    const lightFileName = 'kenney/units/sword_light.png';
    if (game.images.containsKey(lightFileName)) {
      final sprite = Sprite(game.images.fromCache(lightFileName));
      final glowSize = size.x * (0.8 + 0.55 * progress);
      sprite.render(
        canvas,
        position: Vector2(centerX - glowSize / 2, centerY - glowSize / 2),
        size: Vector2.all(glowSize),
        overridePaint: Paint()..color = Colors.white.withOpacity(fade),
      );
      return;
    }

    // Fallback glow: a soft blurred core plus a short bright slash streak,
    // in the game's gold/white palette.
    final glowRadius = size.x * (0.16 + 0.12 * progress);
    canvas.drawCircle(
      Offset(centerX, centerY),
      glowRadius,
      Paint()
        ..color = const Color(0xFFFFF3C4).withOpacity(0.85 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      Offset(centerX, centerY),
      glowRadius * 0.45,
      Paint()..color = Colors.white.withOpacity(0.95 * fade),
    );
    final streakLength = size.x * 0.4 * (0.5 + 0.5 * progress);
    final slashPaint = Paint()
      ..color = Colors.white.withOpacity(0.9 * fade)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX - streakLength * 0.35, centerY + streakLength * 0.3),
      Offset(centerX + streakLength * 0.55, centerY - streakLength * 0.4),
      slashPaint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _healthBar.setHp(unit.hp, unit.maxHp);

    // attackCooldown jumping back up (from ~0 to its max) means the engine
    // just resolved a hit this tick — that's our cue to play the attack
    // animation (or, without one, the lunge fallback).
    final isEngaged = unit.targetEnemyId != null;
    final justHit = isEngaged && unit.attackCooldown > _prevAttackCooldown + 0.01;
    _prevAttackCooldown = unit.attackCooldown;

    final isKungFu = unit.usesKungFu;

    if (_procKind != null) {
      if (justHit) {
        _procAttackElapsed = 0;
      } else if (_procAttackElapsed < 999) {
        _procAttackElapsed += dt;
      }
      if ((unit.x - _procPrevX).abs() > 0.0005) _procWalk += dt * 10;
      _procPrevX = unit.x;
    }

    if (_attackAnim != null) {
      // Panda Warrior keeps its own kung-fu motion (below) instead of the
      // generic attack sheet.
      if (!isKungFu) _updateAnimatedAttack(justHit, dt);
    } else if (justHit && !isKungFu) {
      _lungeTimer = _lungeDuration;
    }

    if (justHit && isKungFu) {
      final enemies = game.provider.gameEngine.activeBattle?.enemies ?? const [];
      for (final e in enemies) {
        if (e.id == unit.targetEnemyId) {
          _kfTargetScreen = game.worldToScreen(e.x, e.y);
          _kfMove = (unit.comboCount - 1) % 3;
          _kfTimer = _kfDuration;
          break;
        }
      }
    }
    if (_kfTimer > 0) {
      _kfTimer = (_kfTimer - dt).clamp(0, _kfDuration);
    }

    if (justHit && unit.type == UnitType.knight) {
      _lightFlashTimer = _lightFlashDuration;
      final enemies = game.provider.gameEngine.activeBattle?.enemies ?? const [];
      for (final e in enemies) {
        if (e.id == unit.targetEnemyId) {
          _boltTargetScreen = game.worldToScreen(e.x, e.y);
          _boltTimer = _boltDuration;
          _boltSeed = DateTime.now().microsecondsSinceEpoch;
          break;
        }
      }
    }
    if (_boltTimer > 0) {
      _boltTimer = (_boltTimer - dt).clamp(0, _boltDuration);
    }
    if (_lightFlashTimer > 0) {
      _lightFlashTimer = (_lightFlashTimer - dt).clamp(0, _lightFlashDuration);
    }

    if (isKungFu && _staticSprite != null) {
      _stanceTime += dt;
      final moved = (unit.x - _kfPrevX).abs() + (unit.y - _kfPrevY).abs();
      _kfPrevX = unit.x;
      _kfPrevY = unit.y;
      if (moved > 0.0005) _walkBob += dt * 14;
      if (unit.hp < _prevHp) _hurtTimer = 0.22;
      _prevHp = unit.hp;
      if (_hurtTimer > 0) _hurtTimer = (_hurtTimer - dt).clamp(0.0, 0.22);

      if (_kfTimer > 0) {
        final pose = _kungFuPose(1 - (_kfTimer / _kfDuration));
        _staticSprite!.position = Vector2(size.x / 2 + pose.offset.dx, size.y / 2 + pose.offset.dy);
        _staticSprite!.angle = pose.angle;
        _staticSprite!.scale = Vector2.all(pose.scale);
      } else if (moved > 0.0005) {
        // Charging / marching: bouncy leaning steps.
        _staticSprite!.position = Vector2(size.x / 2, size.y / 2 - (math.sin(_walkBob)).abs() * 3.0);
        _staticSprite!.angle = 0.12 + 0.05 * math.sin(_walkBob);
        _staticSprite!.scale = Vector2.all(1);
      } else {
        // Ready stance: slow breathing bob, bouncing on the toes.
        final b = math.sin(_stanceTime * 4.0);
        _staticSprite!.position = Vector2(size.x / 2, size.y / 2 - b.abs() * 1.6);
        _staticSprite!.angle = 0.03 * b;
        _staticSprite!.scale = Vector2(1.0, 1.0 + 0.03 * b);
      }
      _staticSprite!.paint = _hurtTimer > 0
          ? (Paint()
            ..colorFilter = ColorFilter.mode(
              const Color(0xFFFF3B30).withOpacity(0.55 * (_hurtTimer / 0.22)),
              BlendMode.srcATop,
            ))
          : Paint();
    }

    double lungeOffsetX = 0;
    if (_staticSprite != null && !isKungFu) {
      if (_lungeTimer > 0) {
        _lungeTimer = (_lungeTimer - dt).clamp(0, _lungeDuration);
        final progress = 1 - (_lungeTimer / _lungeDuration);
        lungeOffsetX = _lungeDistance * (progress < 0.5 ? progress * 2 : (1 - progress) * 2);
        if (_isBigFlyer && unit.facingLeft) lungeOffsetX = -lungeOffsetX;
        _staticSprite!.paint = Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withOpacity((1 - progress) * 0.6),
            BlendMode.srcATop,
          );
      } else {
        _staticSprite!.paint = _fallbackTint == null
            ? Paint()
            : (Paint()..colorFilter = ColorFilter.mode(_fallbackTint!.withOpacity(0.4), BlendMode.srcATop));
      }
    }

    // Phoenix hovers well above the ground with a gentle wing-beat bob.
    double hoverY = 0;
    if (unit.isAirStriker) {
      _hoverTime += dt;
      hoverY = -UnitData.hoverFor(unit.type) + math.sin(_hoverTime * 3.2) * 3.0;
    }

    // Turn toward the target: glide the mirror scale to -1 (left) / 1 (right).
    if (_isBigFlyer) {
      final want = unit.facingLeft ? -1.0 : 1.0;
      if ((_faceScale - want).abs() > 0.001) {
        final step = _turnSpeed * dt;
        _faceScale = _faceScale < want
            ? math.min(want, _faceScale + step)
            : math.max(want, _faceScale - step);
        // Little hop while swinging round (peaks when edge-on).
        _turnHop = math.sin(((_faceScale + 1) / 2) * math.pi) * 6.0;
      } else {
        _turnHop = 0;
      }
      for (final c in [_staticSprite, _walkAnim, _attackAnim]) {
        if (c == null) continue;
        c.scale = Vector2(_faceScale, 1.0);
      }
      hoverY -= _turnHop;
    }
    position = game.worldToScreen(unit.x, unit.y) + Vector2(lungeOffsetX, hoverY);
  }

  /// Swaps the visible layer to the attack sheet for its one-shot duration,
  /// then swaps back to the looping walk sheet.
  void _updateAnimatedAttack(bool justHit, double dt) {
    if (justHit) {
      _attackAnim!.animationTicker?.reset();
      _attackAnim!.playing = true;
      _attackAnim!.opacity = 1;
      _walkAnim!.opacity = 0;
      _attackAnimTimer = _attackAnim!.animationTicker!.totalDuration();
    }
    if (_attackAnimTimer > 0) {
      _attackAnimTimer -= dt;
      if (_attackAnimTimer <= 0) {
        _attackAnim!.playing = false;
        _attackAnim!.opacity = 0;
        _walkAnim!.opacity = 1;
      }
    }
  }
}
