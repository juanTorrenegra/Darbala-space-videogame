import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Small red HP bar above a tutorial target, same look as enemy bars...
///
/// Lives in the world (not as a child of the target) so rotation of the
/// host never drags the bar to a corner. It sits on the top of the host's
/// world bounding box.
class TargetHealthBar extends PositionComponent {
  TargetHealthBar({
    required this.host,
    required this.currentHp,
    required this.maxHp,
    this.isVisible = _alwaysTrue,
  }) : super(
         size: Vector2((host.size.x * 0.8).clamp(16.0, 36.0), 0.5),
         anchor: Anchor.bottomCenter,
         priority: 90,
       );

  final PositionComponent host;
  final int Function() currentHp;
  final int Function() maxHp;
  final bool Function() isVisible;

  static bool _alwaysTrue() => true;

  @override
  void update(double dt) {
    super.update(dt);
    if (!host.isMounted) {
      removeFromParent();
      return;
    }
    final bounds = host.toAbsoluteRect();
    angle = 0;
    position.setValues(bounds.center.dx, bounds.top - 5);
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible()) return;
    final max = maxHp();
    final ratio = max > 0 ? (currentHp() / max).clamp(0.0, 1.0) : 0.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xCC1A0000),
    );
    if (ratio > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x * ratio, size.y),
        Paint()..color = const Color(0xFFE53935),
      );
    }
  }
}
