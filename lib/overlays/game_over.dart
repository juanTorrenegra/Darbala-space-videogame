import 'dart:async';
import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/player.dart';
import 'package:juanshooter/actors/ranged_enemy.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/game_hud.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:juanshooter/utils/game_button.dart';

class GameOverComponent extends PositionComponent
    with TapCallbacks, HasGameReference<MyGame> {
  late final PositionComponent _contentContainer;
  late final RectangleComponent _background;
  late final TextComponent _title;
  late final GameButton _restartButton;
  late final GameButton _menuButton;

  GameOverComponent({MyGame? game}) : super(priority: 9999) {
    if (game != null) {
      this.game = game;
    }
  }

  @override
  Future<void> onLoad() async {
    print('🎮 GameOverComponent.onLoad() iniciando...');
    // ✅ Asegúrate de que el tamaño sea el correcto
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

    // Contenedor para todo el contenido
    _contentContainer = PositionComponent();
    add(_contentContainer);

    // Fondo oscuro semi-transparente
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = Color(0x80000000),
    );
    _contentContainer.add(_background);

    // Crear UI del game over
    await _createUI();

    // Opcional: efecto de aparición sin usar opacity
    _animateAppearance();
    print('🎮 GameOverComponent cargado y visible');
  }

  void _animateAppearance() {
    // Buscar el panel en _contentContainer en lugar de en children
    final panels = _contentContainer.children
        .where((c) => c is RectangleComponent && c.size == Vector2(350, 250))
        .toList();

    if (panels.isNotEmpty) {
      final panel = panels.first as PositionComponent;
      print('🎮 Panel encontrado para animación');

      panel.scale = Vector2.all(1.2);
      panel.add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 3.0, curve: Curves.elasticOut),
        ),
      );
      print('🎮 Animación aplicada al panel');
    } else {
      print('⚠️ No se encontró panel para animar');
      // Buscar también entre los nietos (por si el panel tiene hijos)
      for (final child in _contentContainer.children) {
        if (child is PositionComponent) {
          final grandChildren = child.children
              .where(
                (c) => c is RectangleComponent && c.size == Vector2(350, 250),
              )
              .toList();
          if (grandChildren.isNotEmpty) {
            print('🎮 Panel encontrado en nivel secundario');
            final panel = grandChildren.first as PositionComponent;
            panel.scale = Vector2.all(0.8);
            panel.add(
              ScaleEffect.to(
                Vector2.all(1.0),
                EffectController(duration: 0.4, curve: Curves.elasticOut),
              ),
            );
            break;
          }
        }
      }
    }
  }

  Future<void> _createUI() async {
    // Panel central
    final panel = RectangleComponent(
      size: Vector2(350, 250),
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Color(0xFF2D3047)
        ..style = PaintingStyle.fill,
    );

    final innerPanel = RectangleComponent(
      size: Vector2(346, 246),
      position: Vector2(2, 2),
      paint: Paint()
        ..color = Color(0xFF1A1C2B)
        ..style = PaintingStyle.fill,
    );

    panel.add(innerPanel);
    _contentContainer.add(panel);

    // Título
    _title = TextComponent(
      text: 'NAVE DESTRUIDA',
      position: Vector2(size.x / 2, size.y / 2 - 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 32,
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontFamily: 'Megatrans',
        ),
      ),
    );
    _contentContainer.add(_title);

    // Botón de reinicio
    _restartButton = GameButton(
      position: Vector2(size.x / 2, size.y / 2),
      size: Vector2(200, 50),
      text: 'NUEVO JUEGO',
      onPressed: _restartGame,
    );
    _contentContainer.add(_restartButton);

    // Botón de menú
    _menuButton = GameButton(
      position: Vector2(size.x / 2, size.y / 2 + 70),
      size: Vector2(200, 50),
      text: 'MENÚ PRINCIPAL',
      onPressed: () {
        removeFromParent();
        game.overlays.add('MainMenu');
      },
    );
    _contentContainer.add(_menuButton);
  }

  void _restartGame() async {
    print('🎮 Iniciando nuevo juego...');

    removeFromParent();

    // 2. Recrear jugador
    await game.recreatePlayer();

    // 3. Asegurar que la cámara siga al nuevo jugador
    if (game.camara != null) {
      game.camara!.follow(game.player);
    }
    game.shipsDestroyed = 0;
    game.scoreNotifier.value = 0;
  }
}
