import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/placement_edit_mode.dart';
import 'package:juanshooter/game.dart';

/// Bottom-right tool cluster: scale, move, rotate, delete.
class PlacementToolbar extends PositionComponent
    with HasGameReference<MyGame> {
  PlacementToolbar()
    : super(
        size: Vector2(112, 112),
        anchor: Anchor.bottomRight,
        priority: 1300,
      );

  late final _ToolButton _scale;
  late final _ToolButton _position;
  late final _ToolButton _rotate;
  late final _ToolButton _delete;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _scale = _ToolButton(
      icon: _ToolIcon.scale,
      mode: PlacementEditMode.scale,
    );
    _position = _ToolButton(
      icon: _ToolIcon.position,
      mode: PlacementEditMode.position,
    );
    _rotate = _ToolButton(
      icon: _ToolIcon.rotate,
      mode: PlacementEditMode.rotate,
    );
    _delete = _ToolButton(
      icon: _ToolIcon.delete,
      onPressed: () => game.deleteSelectedPlacement(),
    );
    const gap = 8.0;
    const cell = 52.0;
    _scale.position = Vector2(0, 0);
    _position.position = Vector2(cell + gap, 0);
    _rotate.position = Vector2(0, cell + gap);
    _delete.position = Vector2(cell + gap, cell + gap);
    addAll([_scale, _position, _rotate, _delete]);
  }
}

enum _ToolIcon { scale, position, rotate, delete }

class _ToolButton extends PositionComponent
    with TapCallbacks, HasGameReference<MyGame> {
  _ToolButton({
    required this.icon,
    this.mode,
    this.onPressed,
  }) : super(size: Vector2.all(52), anchor: Anchor.topLeft);

  final _ToolIcon icon;
  final PlacementEditMode? mode;
  final void Function()? onPressed;

  bool get _lit =>
      mode != null && game.placementEditMode == mode;

  @override
  void onTapUp(TapUpEvent event) {
    if (onPressed != null) {
      onPressed!();
      return;
    }
    final next = mode;
    if (next == null) return;
    game.placementEditMode =
        game.placementEditMode == next ? PlacementEditMode.none : next;
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = _lit ? const Color(0xCC00E5FF) : const Color(0x990B1220),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _lit ? 2.2 : 1.2,
    );
    _drawIcon(canvas);
  }

  void _drawIcon(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = Offset(size.x / 2, size.y / 2);

    switch (icon) {
      case _ToolIcon.scale:
        // Outer box and arrows pulling two opposite corners.
        canvas.drawRect(
          Rect.fromCenter(center: c, width: 16, height: 16),
          paint,
        );
        canvas.drawLine(c.translate(-14, -14), c.translate(-7, -7), paint);
        canvas.drawLine(c.translate(14, 14), c.translate(7, 7), paint);
        canvas.drawLine(c.translate(-14, -14), c.translate(-14, -8), paint);
        canvas.drawLine(c.translate(-14, -14), c.translate(-8, -14), paint);
        canvas.drawLine(c.translate(14, 14), c.translate(14, 8), paint);
        canvas.drawLine(c.translate(14, 14), c.translate(8, 14), paint);
      case _ToolIcon.position:
        // Crosshair with arrows on each axis.
        canvas.drawLine(c.translate(-14, 0), c.translate(14, 0), paint);
        canvas.drawLine(c.translate(0, -14), c.translate(0, 14), paint);
        canvas.drawCircle(c, 4, paint);
        _arrow(canvas, paint, c.translate(14, 0), 0);
        _arrow(canvas, paint, c.translate(-14, 0), pi);
        _arrow(canvas, paint, c.translate(0, -14), -pi / 2);
        _arrow(canvas, paint, c.translate(0, 14), pi / 2);
      case _ToolIcon.rotate:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 12),
          -2.2,
          4.2,
          false,
          paint,
        );
        _arrow(canvas, paint, c.translate(10, -7), -0.6);
      case _ToolIcon.delete:
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 8, c.dy - 4, 16, 16),
          paint,
        );
        canvas.drawLine(c.translate(-10, -4), c.translate(10, -4), paint);
        canvas.drawLine(c.translate(-4, -8), c.translate(4, -8), paint);
        canvas.drawLine(c.translate(-3, 1), c.translate(-3, 8), paint);
        canvas.drawLine(c.translate(3, 1), c.translate(3, 8), paint);
    }
  }

  void _arrow(Canvas canvas, Paint paint, Offset tip, double angle) {
    final left = Offset(
      tip.dx + 6 * cos(angle + 2.5),
      tip.dy + 6 * sin(angle + 2.5),
    );
    final right = Offset(
      tip.dx + 6 * cos(angle - 2.5),
      tip.dy + 6 * sin(angle - 2.5),
    );
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }
}
