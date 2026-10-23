import 'dart:math';

import 'package:flame/components.dart';

/// Shared 32-dir facing: [nave_28] is nose-right, then CCW.
class FacingFrames {
  static const List<String> names = [
    'nave_28.webp',
    'nave_29.webp',
    'nave_30.webp',
    'nave_31.webp',
    'nave_00.webp',
    'nave_01.webp',
    'nave_02.webp',
    'nave_03.webp',
    'nave_04.webp',
    'nave_05.webp',
    'nave_06.webp',
    'nave_07.webp',
    'nave_08.webp',
    'nave_09.webp',
    'nave_10.webp',
    'nave_11.webp',
    'nave_12.webp',
    'nave_13.webp',
    'nave_14.webp',
    'nave_15.webp',
    'nave_16.webp',
    'nave_17.webp',
    'nave_18.webp',
    'nave_19.webp',
    'nave_20.webp',
    'nave_21.webp',
    'nave_22.webp',
    'nave_23.webp',
    'nave_24.webp',
    'nave_25.webp',
    'nave_26.webp',
    'nave_27.webp',
  ];

  static const int count = 32;

  static List<String> namesFrom(int start, {String ext = 'webp'}) {
    return [
      for (var i = 0; i < count; i++)
        'nave_${((start + i) % count).toString().padLeft(2, '0')}.$ext',
    ];
  }

  static Future<SpriteAnimation> load(String folder, {int start = 28}) async {
    final sprites = <Sprite>[];
    for (final name in namesFrom(start)) {
      sprites.add(await Sprite.load('$folder/$name'));
    }
    return SpriteAnimation.spriteList(sprites, stepTime: 1);
  }

  static const Map<int, String> enemyFolders = {
    1: 'pruebaEnemy',
    2: 'enemyGreen',
    3: 'enemyGreenDarker',
    4: 'enemyCyan',
    5: 'beholder',
    6: 'donut',
  };

  static final Map<String, SpriteAnimation> _skinCache = {};

  /// Loads 32-dir frames from `assets/images/skins/<folder>/`.
  static Future<SpriteAnimation?> loadSkin(
    String folder, {
    int start = 28,
  }) async {
    final key = '$start:$folder';
    final cached = _skinCache[key];
    if (cached != null) return cached;
    try {
      final loaded = await load('skins/$folder', start: start);
      _skinCache[key] = loaded;
      return loaded;
    } catch (_) {
      try {
        final sprites = <Sprite>[];
        for (final name in namesFrom(start, ext: 'png')) {
          sprites.add(await Sprite.load('skins/$folder/$name'));
        }
        final loaded = SpriteAnimation.spriteList(sprites, stepTime: 1);
        _skinCache[key] = loaded;
        return loaded;
      } catch (e) {
        print('Failed to load skin "$folder": $e');
        return null;
      }
    }
  }

  static Future<SpriteAnimation?> enemyAnimation(int slot) async {
    final folder = enemyFolders[slot];
    if (folder == null) return null;
    return loadSkin(folder, start: 4);
  }

  static Future<SpriteAnimation?> enemyAnimationFolder(String folder) {
    return loadSkin(folder, start: 4);
  }

  static int indexForAngle(double logicalAngle) {
    final tau = 2 * pi;
    var t = -logicalAngle / tau;
    t -= t.floorToDouble();
    return (t * count + 0.5).floor() % count;
  }
}
