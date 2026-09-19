import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

/// Editor prop: tap to select. Move / scale / rotate only run when the
/// matching HUD tool is armed, and only on the selected sprite.
class PlacementSprite extends SpriteComponent
    with TapCallbacks, HasGameReference<MyGame> {
  PlacementSprite({
    required Sprite sprite,
    required this.assetName,
    required Vector2 position,
  }) : super(
         sprite: sprite,
         position: position,
         size: sprite.originalSize.clone(),
         anchor: Anchor.center,
         priority: 4,
       );

  final String assetName;

  static const List<String> assetFiles = [
    '01zombieShip140.png',
    '01zombieShip.png',
    '02zombieShip140.png',
    '02zombieShip.png',
    '03zombieShip140.png',
    '03zombieShip.png',
    'zombieCargoShip140.png',
    'zombieCargoShip800.png',
    'zombieSatelite240px.png',
    'zombieShuttle1px140.png',
    'zombieShuttle2px140.png',
    'zombieShuttle3px140.png',
    'zombieShuttle4px140.png',
    'zombieShuttle5px140.png',
    'zombieTarget01.png',
    'zombieTarget01px140.png',
    'zombieTarget02px140.png',
    'zombieTargetM500.png',
  ];

  static const double minScale = 0.05;
  static const double maxScale = 20;

  bool get isSelected => game.selectedPlacement == this;

  void setUniformScale(double value) {
    scale = Vector2.all(value.clamp(minScale, maxScale));
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.selectPlacement(this);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isSelected) return;
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = const Color(0xFF00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Drops every zombie sprite into [game] at its native pixel size, scattered
  /// around the sector so they can be placed by hand.
  static Future<void> spawnAll(MyGame game) async {
    final rng = Random();
    for (var i = 0; i < assetFiles.length; i++) {
      final name = assetFiles[i];
      final sprite = await Sprite.load('z/$name');
      final col = i % 6;
      final row = i ~/ 6;
      game.universo.add(
        PlacementSprite(
          sprite: sprite,
          assetName: name,
          position: Vector2(
            80 + col * 260 + rng.nextDouble() * 50,
            60 + row * 240 + rng.nextDouble() * 50,
          ),
        ),
      );
    }
  }
}
