import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/potency_bar.dart';
import 'package:juanshooter/overlays/informacion_juego.dart';
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
    final backgroundPaint = Paint()
      ..color = const Color.fromARGB(88, 244, 54, 54).withAlpha(150);

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
    if (percentage > 0.6) return const Color.fromARGB(130, 24, 255, 255);
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

class GameHud extends PositionComponent
    with HasGameReference<MyGame>, TapCallbacks {
  /// Touch controls: native app always; web only in cellular mode.
  JoystickComponent? movementJoystick;
  JoystickComponent? lookJoystick;
  HudButtonComponent? shootButton;
  late final HudButtonComponent menu;
  late final HealthBar healthBar;
  late final HudButtonComponent debugMenuButton;
  late final InformacionJuego informacionJuego;
  late final PotencyBar potencyBar;

  bool get _isSingleStick =>
      game.useTouchControls && game.stickMode == AppStickMode.single;

  /// Web (WASD): dirección normalizada; en otras plataformas permanece en cero.
  final Vector2 _keyboardMovement = Vector2.zero();
  final Vector2 _webMouseLookDelta = Vector2.zero();
  bool _hasWebMouseLookDelta = false;

  bool _spaceWasDown = false;
  bool _chargeHeld = false;

  /// Movimiento: WASD en web; left stick (or the one stick) in app / celular.
  Vector2 get effectiveMovementDelta {
    if (game.useTouchControls) {
      final joystick = movementJoystick;
      if (joystick != null &&
          joystick.isMounted &&
          joystick.direction != JoystickDirection.idle) {
        return joystick.relativeDelta;
      }
      if (!kIsWeb) return Vector2.zero();
    }
    if (kIsWeb) {
      if (_keyboardMovement.length2 > 0.0001) {
        return _keyboardMovement;
      }
      return Vector2.zero();
    }
    return Vector2.zero();
  }

  /// Rotación: mouse en web; look stick in 2-stick; same stick in 1-stick / celular.
  Vector2 get effectiveLookDelta {
    if (game.useTouchControls) {
      if (_isSingleStick) {
        return effectiveMovementDelta;
      }
      final joystick = lookJoystick;
      if (joystick != null &&
          joystick.isMounted &&
          joystick.direction != JoystickDirection.idle) {
        return joystick.relativeDelta;
      }
      return Vector2.zero();
    }
    if (kIsWeb) {
      if (_hasWebMouseLookDelta && _webMouseLookDelta.length2 > 0.0001) {
        return _webMouseLookDelta;
      }
      return Vector2.zero();
    }
    return Vector2.zero();
  }

  /// Actualiza el vector de apuntado desde una posición objetivo en mundo.
  void setWebMouseWorldTarget(Vector2 worldTarget) {
    if (!kIsWeb || !game.player.isMounted) return;
    _webMouseLookDelta.setFrom(worldTarget - game.player.position);
    _hasWebMouseLookDelta = _webMouseLookDelta.length2 > 0.0001;
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
      beginCharge();
    } else if (!spaceDown && _spaceWasDown) {
      releaseCharge();
    }
    _spaceWasDown = spaceDown;
  }

  void beginCharge() {
    if (_chargeHeld || game.paused || !game.player.isMounted) return;
    _chargeHeld = true;
    potencyBar.beginCharge();
    game.player.applyChargeSlowdown();
  }

  void releaseCharge() {
    if (!_chargeHeld) return;
    _chargeHeld = false;
    final shot = potencyBar.releaseCharge();
    game.player.restoreChargeSpeed();
    if (shot != null && !game.paused && game.player.isMounted) {
      game.player.shoot(
        damage: shot.damage,
        sizeScale: shot.sizeScale,
        sfx: shot.shotSound,
      );
    }
  }

  void cancelCharge() {
    if (_chargeHeld) {
      _chargeHeld = false;
      game.player.restoreChargeSpeed();
    }
    potencyBar.cancelCharge();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!kIsWeb || game.cellularMode) return;
    beginCharge();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!kIsWeb || game.cellularMode) return;
    releaseCharge();
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
        radius: 50,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4,
      ),
      background: CircleComponent(
        radius: 80,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
    );
    lookJoystick = JoystickComponent(
      knob: CircleComponent(
        radius: 50,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
      background: CircleComponent(
        radius: 80,
        paint: Paint()
          ..color = Colors.cyan.withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      ),
    );
    shootButton = HudButtonComponent(
      button: AimShootPad(
        fillColor: Colors.cyan.withAlpha(25),
        strokeColor: Colors.cyan.withAlpha(90),
      ),
      buttonDown: AimShootPad(
        fillColor: Colors.cyan.withAlpha(70),
        strokeColor: Colors.cyanAccent.withAlpha(128),
      ),
      onPressed: beginCharge,
      onReleased: releaseCharge,
      onCancelled: releaseCharge,
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
        game.playSfx('menuOpen.mp3');
        game.overlays.add("MainMenu");
        game.pauseBgmMusic();
        // Let the SFX start on this click before the Flame ticker stops.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (game.overlays.isActive('MainMenu')) {
            game.pauseEngine();
          }
        });
      },
    );
    healthBar = HealthBar(
      maxHealth: game.player.maxHitPoints,
      currentHealth: game.player.currentHitPoints,
      width: 300,
      height: 40,
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

    informacionJuego = InformacionJuego()..priority = 1000;
    potencyBar = PotencyBar();

    add(menu);
    add(healthBar);
    add(debugMenuButton);
    add(informacionJuego);
    add(potencyBar);

    applyStickMode();
    _positionComponents();
  }

  void applyStickMode() {
    final move = movementJoystick;
    final look = lookJoystick;
    final shoot = shootButton;
    if (move == null || look == null || shoot == null) return;

    if (!game.useTouchControls) {
      if (move.isMounted) move.removeFromParent();
      if (look.isMounted) look.removeFromParent();
      if (shoot.isMounted) shoot.removeFromParent();
      _positionComponents();
      return;
    }

    if (game.stickMode == AppStickMode.single) {
      if (look.isMounted) look.removeFromParent();
      if (!move.isMounted) add(move);
    } else {
      if (!move.isMounted) add(move);
      if (!look.isMounted) add(look);
    }
    if (!shoot.isMounted) add(shoot);
    _positionComponents();
  }

  void toggleGameInfo() {
    informacionJuego.toggleVisibility();
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
    // HUD lives in the fixed 1280x720 viewport virtual space.
    if (!isLoaded) return;
    final viewSize =
        game.camara?.viewport.virtualSize ??
        Vector2(MyGame.logicalWidth, MyGame.logicalHeight);
    if (viewSize.x <= 0 || viewSize.y <= 0) return;

    size = viewSize;
    position = Vector2.zero();

    final joystickY = viewSize.y * 3 / 4;
    final leftStickPos = Vector2(viewSize.x * 1 / 8, joystickY);
    final rightStickPos = Vector2(viewSize.x * 7 / 8, joystickY);
    movementJoystick?.position = leftStickPos;
    lookJoystick?.position = rightStickPos;
    final shoot = shootButton;
    if (shoot != null) {
      shoot.anchor = Anchor.center;
      if (_isSingleStick) {
        shoot.position = rightStickPos;
      } else {
        shoot.position = Vector2(viewSize.x - 120, 100);
      }
    }
    menu.position = Vector2(viewSize.x / 2 - 15, viewSize.y - 60);
    healthBar.position = Vector2(200, 80);
    debugMenuButton.position = Vector2(10, 40);
    informacionJuego.position = Vector2(80, 260);
    potencyBar.position = Vector2((viewSize.x - potencyBar.size.x) / 2, 24);
  }
}

/// Circular scope / aim pad used as the fire button.
class AimShootPad extends PositionComponent {
  static const double radius = 80;

  final Color fillColor;
  final Color strokeColor;

  AimShootPad({required this.fillColor, required this.strokeColor})
    : super(size: Vector2.all(radius * 2));

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, radius, Paint()..color = fillColor);

    final ring = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    ring.strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 1, ring);
    ring.strokeWidth = 0.65;
    canvas.drawCircle(center, radius * 0.62, ring);
    ring.strokeWidth = 0.6;
    canvas.drawCircle(center, radius * 0.24, ring);

    ring.strokeWidth = 0.7;
    const arm = 16.0;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      ring,
    );

    ring.strokeWidth = 0.6;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final inner = radius - 12;
      final outer = radius - 2;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(a),
          center.dy + inner * math.sin(a),
        ),
        Offset(
          center.dx + outer * math.cos(a),
          center.dy + outer * math.sin(a),
        ),
        ring,
      );
    }
  }
}
