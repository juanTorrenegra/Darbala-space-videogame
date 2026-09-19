import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

/// Bottom-left HUD readout for the selected placement sprite.
class PlacementInspector extends TextComponent
    with HasGameReference<MyGame> {
  PlacementInspector()
    : super(
        text: '',
        anchor: Anchor.bottomLeft,
        priority: 2000,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF00FFFF),
            fontSize: 16,
            fontFamily: 'steel700',
            height: 1.35,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 6),
            ],
          ),
        ),
      );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(18, size.y - 18);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final selected = game.selectedPlacement;
    if (selected == null || !selected.isMounted) {
      text = '';
      return;
    }
    text =
        '${selected.assetName}\n'
        'pos  ${selected.position.x.toStringAsFixed(1)}, '
        '${selected.position.y.toStringAsFixed(1)}\n'
        'scale  ${selected.scale.x.toStringAsFixed(2)}\n'
        'rot  ${(selected.angle * 180 / pi).toStringAsFixed(1)}';
  }
}
