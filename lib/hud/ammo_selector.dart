import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/ammo.dart';

class AmmoSelector extends PositionComponent with HasGameReference<MyGame> {
  static const double buttonSize = 46;
  static const double gap = 8;

  AmmoSelector()
    : super(
        size: Vector2(
          AmmoKind.values.length * buttonSize +
              (AmmoKind.values.length - 1) * gap,
          buttonSize,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (var i = 0; i < AmmoKind.values.length; i++) {
      add(
        AmmoSelectButton(
          kind: AmmoKind.values[i],
          position: Vector2(i * (buttonSize + gap), 0),
          size: Vector2.all(buttonSize),
        ),
      );
    }
  }
}

class AmmoSelectButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  AmmoSelectButton({
    required this.kind,
    required super.position,
    required super.size,
  });

  final AmmoKind kind;
  Sprite? _laserSprite;

  bool get _selected => game.selectedAmmo == kind;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (kind == AmmoKind.laser) {
      _laserSprite = await Sprite.load('laserPointy.png');
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    game.selectedAmmo = kind;
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

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    _drawPreview(canvas);
    canvas.restore();
  }

  void _drawPreview(Canvas canvas) {
    switch (kind) {
      case AmmoKind.laser:
        final sprite = _laserSprite;
        if (sprite == null) return;
        sprite.render(canvas, size: Vector2(28, 15), anchor: Anchor.center);
      case AmmoKind.needle:
        canvas.drawCircle(
          Offset.zero,
          4.5,
          Paint()..color = const Color(0xFFEAF4FF),
        );
      case AmmoKind.plasma:
        canvas.drawCircle(
          Offset.zero,
          11,
          Paint()..color = const Color(0x55E060FF),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 18, height: 8),
          Paint()..color = const Color(0xAAFF9CFF),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 3.5),
          Paint()..color = const Color(0xFFF5E9FF),
        );
      case AmmoKind.ion:
        final stroke = Paint()
          ..color = const Color(0xFFFFC94A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(
          Offset.zero,
          11,
          Paint()..color = const Color(0x44FFB020),
        );
        canvas.drawCircle(Offset.zero, 8, stroke);
        canvas.drawCircle(
          Offset.zero,
          2.2,
          Paint()..color = const Color(0xCCFFE8A0),
        );
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(math.cos(a) * 5, math.sin(a) * 5),
            Offset(math.cos(a) * 9.5, math.sin(a) * 9.5),
            stroke,
          );
        }
    }
  }
}
