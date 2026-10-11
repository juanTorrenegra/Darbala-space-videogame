import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

/// Temporary HUD: swap player sprite folders while testing.
class ShipSkinSelector extends PositionComponent with HasGameReference<MyGame> {
  static const double buttonSize = 40;
  static const double gap = 6;
  static const int slotCount = 5;
  static const double enemyButtonWidth = 88;
  static const int crabSlotCount = 6;
  static const double crabButtonWidth = 44;

  ShipSkinSelector()
    : super(
        size: Vector2(
          _playerRowWidth +
              gap +
              enemyButtonWidth +
              gap +
              crabSlotCount * crabButtonWidth +
              (crabSlotCount - 1) * gap,
          buttonSize,
        ),
      );

  static double get _playerRowWidth =>
      slotCount * buttonSize + (slotCount - 1) * gap;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (var i = 0; i < slotCount; i++) {
      add(
        ShipSkinButton(
          slot: i + 1,
          position: Vector2(i * (buttonSize + gap), 0),
          size: Vector2.all(buttonSize),
        ),
      );
    }
    add(
      EnemyHostilityButton(
        position: Vector2(_playerRowWidth + gap, 0),
        size: Vector2(enemyButtonWidth, buttonSize),
      ),
    );
    final crabOrigin = _playerRowWidth + gap + enemyButtonWidth + gap;
    for (var i = 0; i < crabSlotCount; i++) {
      add(
        CrabSkinButton(
          slot: i + 1,
          position: Vector2(crabOrigin + i * (crabButtonWidth + gap), 0),
          size: Vector2(crabButtonWidth, buttonSize),
        ),
      );
    }
  }
}

class ShipSkinButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  ShipSkinButton({
    required this.slot,
    required super.position,
    required super.size,
  });

  final int slot;

  bool get _selected => game.shipSkinSlot == slot;

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (game.shipSkinSlot == slot) return;
    if (game.player.isMounted) {
      game.player.applyShipSkin(slot);
    } else {
      game.shipSkinSlot = slot;
    }
  }

  @override
  void render(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$slot',
        style: TextStyle(
          fontSize: 28,
          fontFamily: 'ava',
          color: _selected
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

class EnemyHostilityButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  EnemyHostilityButton({required super.position, required super.size});

  bool get _peaceMode => !game.enemyHostilityEnabled;

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    game.setEnemyHostilityEnabled(!game.enemyHostilityEnabled);
  }

  @override
  void render(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'ENEMY',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _peaceMode ? Colors.cyanAccent : Colors.white54,
          shadows: _peaceMode
              ? const [
                  Shadow(color: Colors.cyanAccent, blurRadius: 10),
                  Shadow(color: Colors.cyanAccent, blurRadius: 18),
                ]
              : null,
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

class CrabSkinButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  CrabSkinButton({
    required this.slot,
    required super.position,
    required super.size,
  });

  final int slot;

  bool get _selected => game.crabSkinSlot == slot;

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (game.crabSkinSlot == slot) return;
    game.applyCrabSkin(slot);
  }

  @override
  void render(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'C$slot',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _selected
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

class RangedSkinSelector extends PositionComponent
    with HasGameReference<MyGame> {
  static const double buttonWidth = 44;
  static const double buttonHeight = 40;
  static const double gap = 6;
  static const int slotCount = 6;

  RangedSkinSelector()
    : super(
        size: Vector2(
          slotCount * buttonWidth + (slotCount - 1) * gap,
          buttonHeight,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (var i = 0; i < slotCount; i++) {
      add(
        RangedSkinButton(
          slot: i + 1,
          position: Vector2(i * (buttonWidth + gap), 0),
          size: Vector2(buttonWidth, buttonHeight),
        ),
      );
    }
  }
}

class RangedSkinButton extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  RangedSkinButton({
    required this.slot,
    required super.position,
    required super.size,
  });

  final int slot;

  bool get _selected => game.rangedSkinSlot == slot;

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (game.rangedSkinSlot == slot) return;
    game.applyRangedSkin(slot);
  }

  @override
  void render(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'R$slot',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _selected
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
