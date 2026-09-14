import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Small red HP bar above a tutorial target, same look as enemy bars.
class TargetHealthBar extends PositionComponent {
  TargetHealthBar({
    required this.host,
    required this.currentHp,
    required this.maxHp,
    this.isVisible = _alwaysTrue,
  }) : super(
         size: Vector2((host.size.x * 1.2).clamp(16.0, 36.0), 3),
         anchor: Anchor.center,
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
    final lift = host.size.y * 0.55 - 6;
    position.setValues(0, -lift);
    position.rotate(-host.angle);
    angle = -host.angle;
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible()) return;
    final max = maxHp();
    final ratio = max > 0 ? (currentHp() / max).clamp(0.0, 1.0) : 0.0;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xCC1A0000));
    if (ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x * ratio, size.y),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFFE53935),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xAAFF8A80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }
}
