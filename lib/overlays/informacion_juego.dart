import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/player.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/game_hud.dart';

class InformacionJuego extends PositionComponent with HasGameReference<MyGame> {
  // Configuración
  static const double padding = 8.0;
  static const double fontSize = 9.0;
  static const double lineHeight = 10.0;

  // Text components

  late final List<TextComponent> _infoLines;

  final TextPaint _labelStyle = TextPaint(
    style: TextStyle(color: Colors.grey, fontSize: fontSize),
  );

  final TextPaint _valueStyle = TextPaint(
    style: TextStyle(
      color: Colors.cyan.withAlpha(200),
      fontSize: fontSize,
      //fontWeight: FontWeight.bold,
    ),
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Configurar posición y tamaño
    anchor = Anchor.topLeft;
    position = Vector2(padding, padding);

    // Crear líneas de información
    _infoLines = [];

    // Vida del jugador
    _infoLines.add(
      _createInfoLine(
        index: 0,
        label: 'Vida Jugador',
        value: '${game.player.currentHitPoints}/${game.player.maxHitPoints}',
      ),
    );

    // Posición
    _infoLines.add(
      _createInfoLine(
        index: 1,
        label: 'Posición',
        value:
            '${game.player.position.x.toStringAsFixed(1)}, ${game.player.position.y.toStringAsFixed(1)}',
      ),
    );

    // Naves destruidas
    _infoLines.add(
      _createInfoLine(
        index: 2,
        label: 'Naves Destruidas',
        value: '${game.shipsDestroyed}',
      ),
    );

    // Time Scale
    _infoLines.add(
      _createInfoLine(
        index: 3,
        label: 'Time Scale',
        value: '${game.timeScale.toStringAsFixed(2)}x',
      ),
    );

    // Estado del juego
    _infoLines.add(
      _createInfoLine(
        index: 4,
        label: 'Estado',
        value: game.paused ? 'PAUSADO' : 'ACTIVO',
      ),
    );

    _infoLines.add(
      _createInfoLine(
        index: 5,
        label: 'Velocidad',
        value: game.player.currentSpeed.toStringAsFixed(0),
      ),
    );

    _infoLines.add(
      _createInfoLine(
        index: 6,
        label: 'Zoom',
        value: '${game.cameraZoom.toStringAsFixed(2)}x',
      ),
    );

    // Calcular tamaño del componente
    _calculateSize();

    // Configurar fondo
    _createBackground();
  }

  TextComponent _createInfoLine({
    required int index,
    required String label,
    required String value,
  }) {
    final yPosition = padding + (index * lineHeight);

    // Crear label
    final labelComponent = TextComponent(
      text: '$label: ',
      textRenderer: _labelStyle,
      position: Vector2(4, yPosition),
    );
    add(labelComponent);

    // Crear value
    final valueComponent = TextComponent(
      text: value,
      textRenderer: _valueStyle,
      position: Vector2(80, yPosition),
    );
    add(valueComponent);

    return valueComponent; // Devolvemos el value para poder actualizarlo
  }

  void _calculateSize() {
    double maxWidth = 130;
    double totalHeight = 80;

    size = Vector2(maxWidth, totalHeight);
  }

  void _createBackground() {
    final background = RectangleComponent(
      size: size,
      position: Vector2.zero(),
      paint: Paint()
        ..color = Colors.cyan.withAlpha(20)
        ..style = PaintingStyle.fill,
    );

    // Añadir borde
    final border = RectangleComponent(
      size: size,
      position: Vector2.zero(),
      paint: Paint()
        ..color = Colors.cyan.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Añadir al inicio (al fondo)
    addAll([background]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Actualizar valores en tiempo real
    _updateInfoValues();
  }

  void _updateInfoValues() {
    // Vida del jugador
    if (_infoLines.length > 0) {
      _infoLines[0].text =
          '${game.player.currentHitPoints}/${game.player.maxHitPoints}';
    }

    // Posición
    if (_infoLines.length > 1) {
      _infoLines[1].text =
          '${game.player.position.x.toStringAsFixed(0)}, ${game.player.position.y.toStringAsFixed(0)}';
    }

    // Naves destruidas
    if (_infoLines.length > 2) {
      _infoLines[2].text = '${game.shipsDestroyed}';
    }

    // Time Scale
    if (_infoLines.length > 3) {
      _infoLines[3].text = '${game.timeScale.toStringAsFixed(2)}x';
    }

    // Estado del juego
    if (_infoLines.length > 4) {
      _infoLines[4].text = game.paused ? 'PAUSADO' : 'ACTIVO';
    }

    // Velocidad
    if (_infoLines.length > 5) {
      _infoLines[5].text = game.player.currentSpeed.toStringAsFixed(0);
    }

    // Zoom (mismo valor que `MyGame.cameraZoom` / viewfinder)
    if (_infoLines.length > 6) {
      _infoLines[6].text = '${game.cameraZoom.toStringAsFixed(2)}x';
    }
  }

  // Método para mostrar/ocultar
  void toggleVisibility() {
    if (isMounted) {
      removeFromParent();
    } else {
      game.camara?.viewport.add(this);
    }
  }

  // Método para cambiar posición
  void setPosition(Vector2 newPosition) {
    position = newPosition;
  }
}
