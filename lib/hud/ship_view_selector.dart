import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

class ShipViewSelector extends PositionComponent with HasGameReference<MyGame> {
  static const double buttonSize = 46;
  static const double gap = 8;

  ShipViewSelector()
    : super(
        size: Vector2(
          ShipView.values.length * buttonSize +
              (ShipView.values.length - 1) * gap,
          buttonSize,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      ShipViewButton(
        view: ShipView.isometric,
        label: 'I',
        position: Vector2.zero(),
        size: Vector2.all(buttonSize),
      ),
    );
    add(
      ShipViewButton(
        view: ShipView.perspective,
        label: 'P',
        position: Vector2(buttonSize + gap, 0),
        size: Vector2.all(buttonSize),
      ),
    );
  }
}

class ShipViewButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  ShipViewButton({
    required this.view,
    required this.label,
    required super.position,
    required super.size,
  });

  final ShipView view;
  final String label;

  bool get _selected => game.shipView == view;

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (game.shipView == view) return;
    game.shipView = view;
    if (game.player.isMounted) {
      game.player.applyShipView(view);
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      const Radius.circular(8),
    );
    final selected = _selected;

    canvas.drawRRect(
      rect,
      Paint()
        ..color = selected ? const Color(0x5522E0E8) : const Color(0x2210A0B0),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = selected ? const Color(0xCC7FFFF8) : const Color(0x6670C8D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1.0,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 32,
          fontFamily: 'ava',
          color: selected
              ? Colors.cyanAccent
              : Colors.cyanAccent.withAlpha(120),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
  }
}
