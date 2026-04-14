import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/utils/game_button.dart';

class GameOverComponent extends PositionComponent
    with TapCallbacks, HasGameReference<MyGame> {
  late final PositionComponent _contentContainer;
  late final RectangleComponent _background;
  late final TextComponent _title;
  late final GameButton _restartButton;
  late final GameButton _menuButton;
  late final GameButton _exitButton;

  static const double _letterSpacing = 20;

  GameOverComponent({MyGame? game}) : super(priority: 9999) {
    if (game != null) {
      this.game = game;
    }
  }

  @override
  Future<void> onLoad() async {
    print('🎮 GameOverComponent.onLoad() iniciando...');
    if (game.camara != null) {
      size = game.camara!.viewport.size;
    } else {
      size = game.size;
    }
    if (size.x <= 0 || size.y <= 0) {
      print('⚠️ Advertencia: tamaño inválido $size, usando tamaño por defecto');
      size = Vector2(800, 600);
    }
    position = Vector2.zero();

    _contentContainer = PositionComponent();
    add(_contentContainer);

    // Pantalla completa: cyan muy transparente
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color.fromARGB(48, 0, 220, 255),
    );
    _contentContainer.add(_background);

    await _createUI();
    _animateAppearance();
    print('🎮 GameOverComponent cargado y visible');
  }

  void _animateAppearance() {
    _title.scale = Vector2.all(1.12);
    _title.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.55, curve: Curves.elasticOut),
      ),
    );
  }

  Future<void> _createUI() async {
    const titleGlow = [
      Shadow(color: Color.fromARGB(220, 0, 255, 255), blurRadius: 18),
      Shadow(color: Color.fromARGB(140, 0, 200, 255), blurRadius: 28),
    ];

    _title = TextComponent(
      text: 'NAVE DESTRUIDA',
      position: Vector2(size.x / 2, size.y / 2 - 100),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: 'Megatrans',
          letterSpacing: _letterSpacing,
          shadows: titleGlow,
        ),
      ),
    );
    _contentContainer.add(_title);

    _restartButton = GameButton(
      position: Vector2(size.x / 2, size.y / 2 - 10),
      size: Vector2(420, 48),
      text: 'NUEVO JUEGO',
      textOnly: true,
      letterSpacing: _letterSpacing,
      fontSize: 18,
      onPressed: _restartGame,
    );
    _contentContainer.add(_restartButton);

    _menuButton = GameButton(
      position: Vector2(size.x / 2, size.y / 2 + 50),
      size: Vector2(420, 48),
      text: 'MENÚ PRINCIPAL',
      textOnly: true,
      letterSpacing: _letterSpacing,
      fontSize: 18,
      onPressed: () {
        removeFromParent();
        game.overlays.add('MainMenu');
        _restartGame();
      },
    );
    _contentContainer.add(_menuButton);

    _exitButton = GameButton(
      position: Vector2(size.x / 2, size.y / 2 + 110),
      size: Vector2(420, 48),
      text: 'SALIR',
      textOnly: true,
      letterSpacing: _letterSpacing,
      fontSize: 18,
      onPressed: () {
        SystemNavigator.pop();
      },
    );
    _contentContainer.add(_exitButton);
  }

  void _restartGame() async {
    print('🎮 Iniciando nuevo juego...');

    removeFromParent();
    game.clearAllGameEntities();
    game.deactivateAllEnemies();
    game.clearEnemyBullets();

    await game.recreatePlayer();

    if (game.camara != null) {
      game.camara!.follow(game.player);
    }
    game.shipsDestroyed = 0;
    game.scoreNotifier.value = 0;
  }
}
