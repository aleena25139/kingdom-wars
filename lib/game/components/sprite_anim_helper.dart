// Shared helper for UnitComponent/EnemyComponent: given a character's base
// sprite path (e.g. "assets/kenney/units/knight.png"), looks for optional
// "<name>_walk.png" / "<name>_attack.png" sheets in the same folder.
//
// Sheet convention (this is what artists/designers need to follow):
//   - Single horizontal row of frames, all the SAME height.
//   - Frame width == frame height (each frame is a square), so frame count
//     is auto-detected as (sheet width / sheet height) — no manual frame
//     count anywhere in code. Add as many frames as you like.
//   - Transparent PNG background, same canvas size convention as the base
//     static sprite (256x256 per frame recommended).
// If a sheet isn't found, this returns null and the caller falls back to
// the single static PNG (see UnitComponent/EnemyComponent).
import 'package:flame/components.dart';
import '../kingdom_wars_game.dart';

class SpriteAnimHelper {
  SpriteAnimHelper._();

  static Future<SpriteAnimation?> tryLoad(
    KingdomWarsGame game,
    String basePath,
    String suffix, {
    required double stepTime,
    bool loop = true,
  }) async {
    if (!basePath.endsWith('.png')) return null;
    final animFileName = basePath
        .replaceFirst('assets/', '')
        .replaceFirst(RegExp(r'\.png$'), '_$suffix.png');
    try {
      final image = await game.images.load(animFileName);
      final frameSize = image.height.toDouble();
      if (frameSize <= 0) return null;
      final frameCount = (image.width / frameSize).round().clamp(1, 64);
      return SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: frameCount,
          stepTime: stepTime,
          textureSize: Vector2.all(frameSize),
          loop: loop,
        ),
      );
    } catch (_) {
      return null; // sheet not provided yet — caller uses the static PNG
    }
  }
}
