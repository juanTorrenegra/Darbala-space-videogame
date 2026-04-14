import 'dart:math' as math;

import 'package:flame/components.dart';

import 'package:flame/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:juanshooter/game.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class HealthBar extends PositionComponent with HasGameReference<MyGame> {
  int maxHealth;
  int currentHealth;
  double width;
  double height;

  static const double _labelGap = 10;
  static const double _skewX = -0.14;
  static const double _labelPad = 4;

  final TextStyle _labelStyle = const TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: "steel700",
  );

  /// Ancho reservado a la izquierda para el número (estable según `maxHealth`).
  double _labelReservedWidth = 0;

  static const double _maxHpPulseDuration = 0.5;
  static const double _maxHpPulseAmplitude = 2.0;
  double _maxHpPulseElapsed = 0;
  bool _maxHpPulseActive = false;

  HealthBar({
    required this.maxHealth,
    required this.currentHealth,
    this.width = 200,
    this.height = 10,
  }) {
    _refreshLabelReserve();
    size = Vector2(layoutWidth, height);
  }

  /// Ancho total: número + separación + barra (para centrar el HUD).
  double get layoutWidth => _labelReservedWidth + _labelGap + width;

  void _refreshLabelReserve() {
    final tpMax = TextPainter(
      text: TextSpan(text: '$maxHealth', style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final tpCur = TextPainter(
      text: TextSpan(text: '$currentHealth', style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    _labelReservedWidth = math.max(tpMax.width, tpCur.width) + _labelPad * 2;
    size = Vector2(layoutWidth, height);
  }

  double _labelPulseScale() {
    if (!_maxHpPulseActive) return 1.0;
    final t = (_maxHpPulseElapsed / _maxHpPulseDuration).clamp(0.0, 1.0);
    return 1.0 + _maxHpPulseAmplitude * math.sin(math.pi * t);
  }

  void _startMaxHpPulse() {
    _maxHpPulseElapsed = 0;
    _maxHpPulseActive = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_maxHpPulseActive) {
      // `dt` sigue al timeScale del juego; normalizamos para ~0.5s reales.
      final realDt = dt / game.timeScale.clamp(0.001, 100.0);
      _maxHpPulseElapsed += realDt;
      if (_maxHpPulseElapsed >= _maxHpPulseDuration) {
        _maxHpPulseActive = false;
        _maxHpPulseElapsed = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final labelPainter = TextPainter(
      text: TextSpan(text: '$currentHealth', style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _labelReservedWidth);

    final labelX = _labelReservedWidth - labelPainter.width;
    final labelY = (height - labelPainter.height) / 2;
    final cx = labelX + labelPainter.width / 2;
    final cy = labelY + labelPainter.height / 2;
    final scale = _labelPulseScale();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);
    labelPainter.paint(canvas, Offset(labelX, labelY));
    canvas.restore();

    final borderRadius = height / 2;
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(borderRadius),
    );
    final backgroundPaint = Paint()..color = Colors.red.withAlpha(150);

    final healthPercentage = maxHealth > 0
        ? (currentHealth / maxHealth).clamp(0.0, 1.0)
        : 0.0;
    final healthWidth = width * healthPercentage;

    final healthPaint = Paint()
      ..color = _getHealthColor(healthPercentage)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(_labelReservedWidth + _labelGap, 0);
    canvas.transform(vm.Matrix4.skewX(_skewX).storage);
    canvas.drawRRect(backgroundRect, backgroundPaint);
    if (healthWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, healthWidth, height),
        Radius.circular(borderRadius),
      );
      canvas.drawRRect(fillRect, healthPaint);
    }
    canvas.restore();
  }

  Color _getHealthColor(double percentage) {
    if (percentage > 0.6) return Colors.cyanAccent;
    if (percentage > 0.3) return Colors.orange;
    return Colors.red;
  }

  void updateHealth(int current, int max) {
    final prevMax = maxHealth;
    final maxIncreased = max > prevMax;
    final maxChanged = max != maxHealth;
    currentHealth = current;
    maxHealth = max;
    if (maxIncreased) {
      _startMaxHpPulse();
    }
    if (maxChanged) {
      _refreshLabelReserve();
    } else {
      size = Vector2(layoutWidth, height);
    }
  }
}

class GameHud extends PositionComponent with HasGameReference<MyGame> {
  late final JoystickComponent movementJoystick;
  late final JoystickComponent lookJoystick;
  late final HudButtonComponent shootButton;
  late final HudButtonComponent menu;
  late final HealthBar healthBar;
  late final HudButtonComponent debugMenuButton;

  /// Web (WASD): dirección normalizada; en otras plataformas permanece en cero.
  final Vector2 _keyboardMovement = Vector2.zero();

  bool _spaceWasDown = false;

  /// Movimiento efectivo: en web, WASD tiene prioridad sobre el joystick; si no hay teclas, se usa el joystick.
  Vector2 get effectiveMovementDelta {
    if (kIsWeb && _keyboardMovement.length2 > 0.0001) {
      return _keyboardMovement;
    }
    if (movementJoystick.direction != JoystickDirection.idle) {
      return movementJoystick.relativeDelta;
    }
    return Vector2.zero();
  }

  void _syncWebKeyboardInput() {
    if (!kIsWeb) return;
    final kb = HardwareKeyboard.instance;
    double x = 0;
    double y = 0;
    if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyW)) y -= 1;
    if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyS)) y += 1;
    if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyA)) x -= 1;
    if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyD)) x += 1;
    _keyboardMovement.setValues(x, y);
    if (_keyboardMovement.length2 > 0) {
      _keyboardMovement.normalize();
    }

    final spaceDown = kb.isLogicalKeyPressed(LogicalKeyboardKey.space);
    if (spaceDown && !_spaceWasDown && !game.paused) {
      game.player.shoot();
    }
    _spaceWasDown = spaceDown;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncWebKeyboardInput();
  }

  @override
  Future<void> onLoad() async {
    movementJoystick = JoystickComponent(
      knob: CircleComponent(
        radius: 30,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
    );
    lookJoystick = JoystickComponent(
      knob: CircleComponent(
        radius: 30,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
    );
    shootButton = HudButtonComponent(
      button: CircleComponent(
        radius: 40,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(50)
          ..style = PaintingStyle.fill
          ..strokeWidth = 0.3,
      ),
      onPressed: () => game.player.shoot(),
    );

    menu = HudButtonComponent(
      button: TextComponent(
        text: "A",
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 50,
            fontFamily: "ava",
            color: Colors.cyanAccent.withValues(alpha: 120),
          ),
        ),
      ),
      onPressed: () {
        game.overlays.add("MainMenu");
        //game.setTimeScale(0.0);
        game.pauseEngine();
        game.pauseBgmMusic();
      },
    );
    healthBar = HealthBar(
      maxHealth: game.player.maxHitPoints,
      currentHealth: game.player.currentHitPoints,
      width: 200,
      height: 10,
    );

    debugMenuButton = HudButtonComponent(
      button: RectangleComponent(
        size: Vector2(30, 30),
        paint: Paint()
          ..color = Colors.green.withAlpha(20)
          ..style = PaintingStyle.fill,
      ),
      onPressed: () {
        game.overlays.add('DebugMenu');
      },
    );

    add(menu);
    add(movementJoystick);
    add(lookJoystick);
    add(shootButton);
    add(healthBar);
    add(debugMenuButton);

    _positionComponents();
  }

  void updateHealthBar(int currentHealth, int maxHealth) {
    healthBar.updateHealth(currentHealth, maxHealth);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _positionComponents();
  }

  void _positionComponents() {
    // Solo posiciona si los componentes están cargados y el tamaño es válido
    if (isLoaded && game.size.x > 0 && game.size.y > 0) {
      final margin = 40.0; // Ajusta este valor según necesites
      final joystickSize = 150.0; // Tamaño del joystick (radio + margen)
      movementJoystick.position = Vector2(
        margin + joystickSize / 2,
        game.size.y - margin - joystickSize / 2,
      );
      lookJoystick.position = Vector2(
        game.size.x - margin - joystickSize / 2,
        game.size.y - margin - joystickSize / 2,
      );
      shootButton.position = Vector2(game.size.x - 160, 20);
      menu.position = Vector2(game.size.x / 2 - 15, game.size.y - 60);
      healthBar.position = Vector2(
        (game.size.x - healthBar.layoutWidth) / 2,
        20,
      );
      debugMenuButton.position = Vector2(10, 40);
    }
  }
}
