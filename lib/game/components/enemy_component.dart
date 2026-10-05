// Renders a single enemy. Art fallback chain, checked once in onLoad():
//   1. "<name>_walk.png" + "<name>_attack.png" sheets  -> SpriteAnimation.
//   2. Only the static "<name>.png"                     -> single image with
//      a lunge + flash standing in for the attack.
//   3. NO PNG at all (this was the bug: Lizards/Monsters were invisible
//      because their art files aren't shipped)          -> the enemy is drawn
//      in code by CreaturePainter, with real attack poses:
//        Lizard  alternates BITE (jaws + teeth) and CLAW (front-leg rake)
//        Monster alternates CLAW SLAM and fanged BITE
//      plus bite-mark / claw-slash impact effects on whatever got hit.
// All movement/targeting/damage is BattleEngine's job; this only reads the
// Enemy model (position, strikeCount, aim) and draws.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/enemy_data.dart';
import '../../models/enemy.dart';
import '../../services/creature_painter.dart';
import '../../services/sprite_registry.dart';
import '../kingdom_wars_game.dart';
import 'health_bar_component.dart';
import 'shadow_helper.dart';
import 'sprite_anim_helper.dart';

class EnemyComponent extends PositionComponent {
  final Enemy enemy;
  final KingdomWarsGame game;

  late final HealthBarComponent _healthBar;
  SpriteComponent? _staticSprite;
  SpriteAnimationComponent? _walkAnim;
  SpriteAnimationComponent? _attackAnim;

  // Procedural-art mode (no PNG available).
  CreatureKind? _kind;
  double _walkPhase = 0;
  double _attackElapsed = 999; // seconds since the current strike started
  int _attackStyle = 0;
  int _seenStrikeCount = 0;
  double _prevX = 0;
  double _prevY = 0;

  // Static-sprite lunge fallback.
  double _lungeTimer = 0;
  double _attackAnimTimer = 0;
  int _prevHp = 0;
  double _hurtTimer = 0;
  static const double _lungeDuration = 0.15;
  double get _lungeDistance => enemy.type == EnemyType.lizard ? 16.0 : 6.0; // px

  static double _renderSizeFor(EnemyType type) {
    switch (type) {
      case EnemyType.monster:
        return 60.0; // big brute
      case EnemyType.lizard:
        return 72.0; // big, imposing predator
      case EnemyType.stormKnight:
        return 66.0;
      case EnemyType.emberHound:
        return 46.0;
      case EnemyType.stormCaller:
        return 56.0;
      case EnemyType.thunderTitan:
        return 96.0; // towering boss
      case EnemyType.blackDragon:
        return 120.0; // huge flying dragon
      case EnemyType.goblin:
        return 36.0;
      case EnemyType.skeleton:
      case EnemyType.skeletonArcher:
        return 32.0;
    }
  }

  double get _attackDuration => enemy.type == EnemyType.monster || enemy.type == EnemyType.thunderTitan
      ? 0.7
      : (enemy.type == EnemyType.lizard ? 0.5 : 0.45);

  // Permanent colour wash used when a storm enemy is drawn with a stand-in
  // sprite because its own PNG hasn't been added to assets yet.
  Color? _fallbackTint;

  // Black dragon: true while the stand-in (good dragon) art is shown, which
  // faces right, so it must be mirrored the other way round.
  bool _artFacesRight = false;
  double _bobTime = 0;

  EnemyComponent({required this.enemy, required this.game})
      : super(size: Vector2.all(_renderSizeFor(enemy.type)), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = game.worldToScreen(enemy.x, enemy.y);
    _prevX = enemy.x;
    _prevY = enemy.y;
    _healthBar = HealthBarComponent(
      size: Vector2(math.max(24.0, size.x * 0.8), 4),
      position: Vector2(size.x / 2, -6),
      foregroundColor: AppColors.crimsonEvil,
    );
    add(_healthBar);

    final basePath = SpriteRegistry.pathFor(enemy.spriteName);
    final fileName = basePath.replaceFirst('assets/', '');
    final walkAnimation = await SpriteAnimHelper.tryLoad(game, basePath, 'walk', stepTime: 0.12);
    final attackAnimation =
        await SpriteAnimHelper.tryLoad(game, basePath, 'attack', stepTime: 0.08, loop: false);

    if (walkAnimation != null) {
      _walkAnim = SpriteAnimationComponent(animation: walkAnimation, size: size, removeOnFinish: false);
      add(_walkAnim!);
      if (attackAnimation != null) {
        _attackAnim = SpriteAnimationComponent(
          animation: attackAnimation,
          size: size,
          removeOnFinish: false,
          playing: false,
        );
        _attackAnim!.opacity = 0;
        add(_attackAnim!);
      }
    } else if (game.images.containsKey(fileName)) {
      _staticSprite = SpriteComponent(sprite: Sprite(game.images.fromCache(fileName)), size: size);
      if (enemy.type == EnemyType.lizard || enemy.type == EnemyType.blackDragon) {
        // Centre-anchored so it can be flipped to face whoever it is mauling
        // (the lizard / black dragon art faces left).
        _staticSprite!.anchor = Anchor.center;
        _staticSprite!.position = size / 2;
      }
      add(_staticSprite!);
    } else {
      // Storm enemies whose own PNG isn't shipped yet: borrow an existing
      // enemy's art and colour-wash it so it still looks distinct.
      final def = EnemyData.defFor(enemy.type);
      final fb = def.fallbackSprite;
      final fbFile = fb == null ? null : SpriteRegistry.pathFor(fb).replaceFirst('assets/', '');
      if (fbFile != null && game.images.containsKey(fbFile)) {
        _staticSprite = SpriteComponent(sprite: Sprite(game.images.fromCache(fbFile)), size: size);
        if (def.fallbackTint != 0) _fallbackTint = Color(def.fallbackTint);
        if (enemy.type == EnemyType.blackDragon) {
          // Stand-in art is the good dragon, which faces RIGHT: mirror it.
          _staticSprite!.anchor = Anchor.center;
          _staticSprite!.position = size / 2;
          _artFacesRight = true;
        }
        add(_staticSprite!);
      } else {
        // No art file shipped for this enemy -> draw it in code.
        _kind = CreaturePainter.kindFor(fb ?? enemy.spriteName);
        if (def.fallbackTint != 0) _fallbackTint = Color(def.fallbackTint);
      }
    }
    _seenStrikeCount = enemy.strikeCount;
    _prevHp = enemy.hp;
  }

  // Mind-controlled (charmed) enemies glow green: they fight for the player.
  static const Color _charmTint = Color(0xFF69F0AE);

  Color? get _tint => enemy.charmed
      ? _charmTint
      : enemy.slowDurationRemaining > 0
      ? AppColors.diamondBlue
      : (enemy.burnDurationRemaining > 0 ? AppColors.orange : _fallbackTint);

  @override
  void render(Canvas canvas) {
    drawGroundShadow(canvas, game, size);

    if (_kind != null) {
      final tint = _tint;
      final rect = Rect.fromLTWH(-size.x * 0.3, -size.y * 0.3, size.x * 1.6, size.y * 1.6);
      if (tint != null) {
        canvas.saveLayer(
          rect,
          Paint()..colorFilter = ColorFilter.mode(tint.withOpacity(0.45), BlendMode.srcATop),
        );
      }
      final attacking = _attackElapsed < _attackDuration;
      CreaturePainter.paint(
        canvas,
        Size(size.x, size.y),
        _kind!,
        walk: _walkPhase,
        attack: attacking ? _attackElapsed / _attackDuration : 0,
        style: _attackStyle,
        facingLeft: enemy.facingLeft,
      );
      if (tint != null) canvas.restore();
    }

    super.render(canvas); // health bar + any PNG layers

    if (enemy.type == EnemyType.lizard && _staticSprite != null && _attackElapsed < _attackDuration) {
      _renderLizardWeapons(canvas);
    }

    if (_attackElapsed < _attackDuration + 0.2) _renderImpact(canvas);
  }

  /// Lizard attack overlay on top of the PNG: on a BITE the jaws gape wide
  /// and slam shut showing two rows of long fangs; on a CLAW strike three
  /// big talons rake forward from its hand. Drawn in the sprite's local
  /// space and mirrored when the lizard faces right.
  void _renderLizardWeapons(Canvas canvas) {
    final a = (_attackElapsed / _attackDuration).clamp(0.0, 1.0);
    final open = math.sin(a * math.pi); // 0 -> 1 -> 0 across the strike
    final left = enemy.facingLeft;
    double mx(double x) => left ? x : size.x - x;
    final dir = left ? -1.0 : 1.0;
    final k = size.x / 56.0;

    if (_attackStyle == 0) {
      // BITE
      final mouth = Offset(mx(size.x * 0.06), size.y * 0.42);
      final gap = open * 7.0 * k;
      canvas.drawOval(
        Rect.fromCenter(center: mouth.translate(dir * 2 * k, 0), width: 14 * k, height: gap + 2 * k),
        Paint()..color = const Color(0xFF5A0A0A).withOpacity(0.9),
      );
      final fang = Paint()..color = Colors.white.withOpacity(0.55 + 0.45 * open);
      for (var i = 0; i < 4; i++) {
        final x = mouth.dx - dir * (i * 3.6 * k - 3.0 * k); // front tooth -> back
        final len = (5.5 - (i == 0 ? 0 : 0.6 * i)) * k * (0.6 + 0.6 * open);
        final upper = Path()
          ..moveTo(x - 1.5 * k, mouth.dy - gap / 2)
          ..lineTo(x + 1.5 * k, mouth.dy - gap / 2)
          ..lineTo(x, mouth.dy - gap / 2 + len)
          ..close();
        final lower = Path()
          ..moveTo(x - 1.5 * k, mouth.dy + gap / 2)
          ..lineTo(x + 1.5 * k, mouth.dy + gap / 2)
          ..lineTo(x, mouth.dy + gap / 2 - len)
          ..close();
        canvas.drawPath(upper, fang);
        canvas.drawPath(lower, fang);
      }
    } else {
      // CLAW RAKE: three talons sweeping down and forward from the hand.
      final hand = Offset(mx(size.x * 0.14), size.y * 0.68);
      final sweep = open * 15 * k;
      final talon = Paint()
        ..color = Colors.white.withOpacity(0.5 + 0.5 * open)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * k
        ..strokeCap = StrokeCap.round;
      final blood = Paint()
        ..color = const Color(0xFFD32F2F).withOpacity(0.75 * open)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * k
        ..strokeCap = StrokeCap.round;
      for (var i = -1; i <= 1; i++) {
        final start = hand.translate(dir * (i * 3.2 * k - 4 * k), i * 4.0 * k - 6 * k);
        final end = start.translate(dir * sweep * 0.9, sweep);
        canvas.drawLine(start, end, talon);
        canvas.drawLine(start.translate(0, 1.2 * k), end.translate(0, 1.2 * k), blood);
      }
    }
  }

  /// Bite marks / claw slashes drawn on whatever the last strike hit.
  void _renderImpact(Canvas canvas) {
    if (enemy.isRanged) return; // arrows have their own projectile visual
    final t = _attackElapsed / _attackDuration;
    if (t < 0.4 || t > 1.25) return; // only right after the strike connects
    final fade = (1.25 - t).clamp(0.0, 1.0);
    final aim = game.worldToScreen(enemy.aimX, enemy.aimY) - position + Vector2(size.x / 2, size.y / 2);
    final c = Offset(aim.x, aim.y);
    final k = size.x / 40.0 * (enemy.type == EnemyType.lizard ? 1.35 : 1.0);
    final biteStrike = (_attackStyle == 0 && enemy.type == EnemyType.lizard) ||
        (_attackStyle == 1 && (enemy.type == EnemyType.monster || enemy.type == EnemyType.thunderTitan));

    if (biteStrike) {
      // Two rows of fang punctures + a few blood-red drops.
      final tooth = Paint()..color = Colors.white.withOpacity(fade);
      for (var i = -2; i <= 2; i++) {
        final x = c.dx + i * 3.4 * k;
        final up = Path()
          ..moveTo(x - 1.6 * k, c.dy - 4 * k)
          ..lineTo(x + 1.6 * k, c.dy - 4 * k)
          ..lineTo(x, c.dy - 0.5 * k)
          ..close();
        final down = Path()
          ..moveTo(x - 1.6 * k, c.dy + 4 * k)
          ..lineTo(x + 1.6 * k, c.dy + 4 * k)
          ..lineTo(x, c.dy + 0.5 * k)
          ..close();
        canvas.drawPath(up, tooth);
        canvas.drawPath(down, tooth);
      }
      final drop = Paint()..color = const Color(0xFFD32F2F).withOpacity(fade);
      canvas.drawCircle(c + Offset(-3 * k, 6 * k), 1.4 * k, drop);
      canvas.drawCircle(c + Offset(4 * k, 7.5 * k), 1.1 * k, drop);
    } else {
      // Three parallel claw rakes.
      final slash = Paint()
        ..color = Colors.white.withOpacity(fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * k
        ..strokeCap = StrokeCap.round;
      final red = Paint()
        ..color = const Color(0xFFD32F2F).withOpacity(fade * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * k
        ..strokeCap = StrokeCap.round;
      for (var i = -1; i <= 1; i++) {
        final o = i * 4.5 * k;
        final a = Offset(c.dx + o - 5 * k, c.dy - 8 * k);
        final b = Offset(c.dx + o + 5 * k, c.dy + 8 * k);
        canvas.drawLine(a, b, slash);
        canvas.drawLine(a + Offset(1.5 * k, 0), b + Offset(1.5 * k, 0), red);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _healthBar.setPercent(enemy.hp / enemy.maxHp);
    if (enemy.hp < _prevHp) _hurtTimer = 0.12;
    _prevHp = enemy.hp;
    if (_hurtTimer > 0) _hurtTimer = (_hurtTimer - dt).clamp(0.0, 0.12);

    // A new strike started: restart the attack pose and alternate the style
    // (Lizard: bite / claw / bite ..., Monster: claw / bite / claw ...).
    final justStruck = enemy.strikeCount != _seenStrikeCount;
    if (justStruck) {
      _seenStrikeCount = enemy.strikeCount;
      _attackElapsed = 0;
      _attackStyle = (enemy.strikeCount + 1) % 2;
      _lungeTimer = _lungeDuration;
    } else if (_attackElapsed < 999) {
      _attackElapsed += dt;
    }

    // Walk cycle only advances while actually moving.
    final moved = (enemy.x - _prevX).abs() + (enemy.y - _prevY).abs();
    _prevX = enemy.x;
    _prevY = enemy.y;
    if (moved > 0.0005) {
      _walkPhase += dt * (6 + 5 * enemy.effectiveSpeed);
    }

    final tint = _tint;

    if (_attackAnim != null) {
      _updateAnimatedAttack(justStruck, dt);
      final activeLayer = (_attackAnimTimer > 0) ? _attackAnim! : _walkAnim!;
      activeLayer.paint = tint != null
          ? (Paint()..colorFilter = ColorFilter.mode(tint.withOpacity(0.5), BlendMode.srcATop))
          : Paint();
    } else if (_walkAnim != null) {
      _walkAnim!.paint = tint != null
          ? (Paint()..colorFilter = ColorFilter.mode(tint.withOpacity(0.5), BlendMode.srcATop))
          : Paint();
    }

    double lungeOffsetX = 0;
    if (enemy.type == EnemyType.lizard && _staticSprite != null) {
      // Lizard attack: rear back (wind-up), then snap forward with a forward
      // pitch (the strike), then settle. Walking = heavy predator sway.
      final dir = enemy.facingLeft ? -1.0 : 1.0;
      final attacking = _attackElapsed < _attackDuration;
      final a = attacking ? _attackElapsed / _attackDuration : 0.0;
      double off = 0, pitch = 0, sx = 1, sy = 1;
      if (attacking) {
        if (a < 0.3) {
          final w = a / 0.3;
          off = -dir * 7 * w; // rear back
          pitch = -0.14 * w; // head lifts
        } else if (a < 0.6) {
          final k = (a - 0.3) / 0.3;
          off = dir * (-7 + 27 * k); // explosive lunge
          pitch = 0.22 * k - 0.14 * (1 - k); // head snaps down
          sx = 1 + 0.12 * k;
          sy = 1 - 0.06 * k;
        } else {
          final r = (a - 0.6) / 0.4;
          off = dir * 20 * (1 - r);
          pitch = 0.22 * (1 - r);
          sx = 1 + 0.12 * (1 - r);
        }
      } else if (moved > 0.0005) {
        pitch = 0.05 * math.sin(_walkPhase * 1.4);
        sy = 1 + 0.02 * math.sin(_walkPhase * 2.8);
      }
      lungeOffsetX = off;
      _staticSprite!.angle = enemy.facingLeft ? -pitch : pitch;
      _staticSprite!.scale = Vector2((enemy.facingLeft ? 1 : -1) * sx, sy);
      final hurt = _hurtTimer > 0;
      final strikeFlash = attacking && a > 0.3 && a < 0.6;
      final flashColor = hurt ? Colors.white : const Color(0xFFFF3B30);
      final flashAmt = hurt ? 0.55 * (_hurtTimer / 0.12) : (strikeFlash ? 0.28 : 0.0);
      _staticSprite!.paint = flashAmt > 0
          ? (Paint()..colorFilter = ColorFilter.mode(flashColor.withOpacity(flashAmt), BlendMode.srcATop))
          : (tint != null
              ? (Paint()..colorFilter = ColorFilter.mode(tint.withOpacity(0.5), BlendMode.srcATop))
              : Paint());
    } else if (_staticSprite != null) {
      if (_lungeTimer > 0) {
        _lungeTimer = (_lungeTimer - dt).clamp(0, _lungeDuration);
        final progress = 1 - (_lungeTimer / _lungeDuration);
        final dir = enemy.facingLeft ? -1.0 : 1.0;
        lungeOffsetX = dir * _lungeDistance * (progress < 0.5 ? progress * 2 : (1 - progress) * 2);
        final flashOpacity = (1 - progress) * 0.6;
        _staticSprite!.paint = Paint()
          ..colorFilter = ColorFilter.mode(
            (tint ?? Colors.white).withOpacity(flashOpacity.clamp(0.0, 1.0)),
            BlendMode.srcATop,
          );
      } else {
        _staticSprite!.paint = _hurtTimer > 0
            ? (Paint()
              ..colorFilter = ColorFilter.mode(
                Colors.white.withOpacity(0.5 * (_hurtTimer / 0.12)),
                BlendMode.srcATop,
              ))
            : (tint != null
                ? (Paint()..colorFilter = ColorFilter.mode(tint.withOpacity(0.5), BlendMode.srcATop))
                : Paint());
      }
    }

    // Black dragon: face the way it is looking and hover up and down.
    double hoverBob = 0;
    if (enemy.type == EnemyType.blackDragon) {
      _bobTime += dt;
      hoverBob = -14 + 4 * math.sin(_bobTime * 3.0);
      if (_staticSprite != null) {
        final mirror = _artFacesRight ? enemy.facingLeft : !enemy.facingLeft;
        _staticSprite!.scale = Vector2(mirror ? -1.0 : 1.0, 1.0);
      }
    }

    // Storm Caller: while casting he rears back and lifts his arm to the sky.
    double castLift = 0;
    if (enemy.type == EnemyType.stormCaller && _staticSprite != null && _attackElapsed < 0.9) {
      final a = _attackElapsed / 0.9;
      final raise = math.sin(a * math.pi);
      castLift = -8 * raise;
      _staticSprite!.angle = (enemy.facingLeft ? 0.16 : -0.16) * raise;
    } else if (enemy.type == EnemyType.stormCaller && _staticSprite != null) {
      _staticSprite!.angle = 0;
    }
    position = game.worldToScreen(enemy.x, enemy.y) + Vector2(lungeOffsetX, castLift + hoverBob);
  }

  void _updateAnimatedAttack(bool justStruck, double dt) {
    if (justStruck) {
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
