import 'dart:math';

import 'package:flame/components.dart';

/// A circular body the player cannot occupy. Radius matches a [CircleHitbox]
/// that fills the sprite: half of the shortest scaled side.
mixin SolidBody on PositionComponent {
  double get bodyRadius {
    final sx = size.x * scale.x.abs();
    final sy = size.y * scale.y.abs();
    return min(sx, sy) * 0.5;
  }
}
