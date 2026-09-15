import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/game_hud.dart';

enum ShootHintKind { off, tapLaser, chargeLaser }

/// Tutorial callout for the shoot button: flashing cyan glow, diagonal
/// label + connector, and (for charge) a silent copy of the potency bar.
class TutorialShootHint extends PositionComponent
    with HasGameReference<MyGame> {
  TutorialShootHint() : super(priority: 200, anchor: Anchor.topLeft);

  ShootHintKind _kind = ShootHintKind.off;
  double _elapsed = 0;
  double _idleAfterInterrupt = 0;
  bool _interrupted = false;

  static const double _tapOnOffPeriod = 0.125; // 4 on+off in 1s
  static const double _tapBurstSeconds = 1.0;
  static const double _tapPauseSeconds = 1.0;
  static const double _chargeOnSeconds = 3.0;
  static const double _chargePauseSeconds = 1.0;
  static const double _resumeAfterIdle = 2.0;

  void startTapLaser() {
    _kind = ShootHintKind.tapLaser;
    _elapsed = 0;
    _interrupted = false;
    _idleAfterInterrupt = 0;
  }

  void startChargeLaser() {
    _kind = ShootHintKind.chargeLaser;
    _elapsed = 0;
    _interrupted = false;
    _idleAfterInterrupt = 0;
  }

  void stop() {
    _kind = ShootHintKind.off;
    _interrupted = false;
  }

  bool get _playerUsingShoot =>
      game.hud.isLoaded && game.hud.isShootHeld;

  @override
  void update(double dt) {
    super.update(dt);
    if (_kind == ShootHintKind.off) return;

    final realDt = dt / game.timeScale.clamp(0.001, 100.0);

    if (_playerUsingShoot) {
      _interrupted = true;
      _idleAfterInterrupt = 0;
      return;
    }

    if (_interrupted) {
      _idleAfterInterrupt += realDt;
      if (_kind == ShootHintKind.chargeLaser) {
        if (_idleAfterInterrupt >= _resumeAfterIdle) {
          _interrupted = false;
          _elapsed = 0;
        }
      } else {
        // Tap hint: resume as soon as they are not shooting.
        _interrupted = false;
        _elapsed = 0;
      }
      return;
    }

    _elapsed += realDt;
  }

  /// Visible this frame (glow + text + line).
  bool get _lit {
    if (_kind == ShootHintKind.off || _interrupted || _playerUsingShoot) {
      return false;
    }
    if (_kind == ShootHintKind.tapLaser) {
      final cycle = _tapBurstSeconds + _tapPauseSeconds;
      final t = _elapsed % cycle;
      if (t >= _tapBurstSeconds) return false;
      // Four on/off pairs in 1s: on 0.125, off 0.125, …
      return (t / _tapOnOffPeriod).floor().isEven;
    }
    // Charge: 3s on, 1s off.
    final cycle = _chargeOnSeconds + _chargePauseSeconds;
    return (_elapsed % cycle) < _chargeOnSeconds;
  }

  double get _chargeFill {
    if (_kind != ShootHintKind.chargeLaser || !_lit) return 0;
    final t = _elapsed % (_chargeOnSeconds + _chargePauseSeconds);
    return (t / _chargeOnSeconds).clamp(0.0, 1.0);
  }

  Vector2 _buttonCenter() {
    final shoot = game.hud.shootButton;
    if (shoot != null && shoot.isMounted) {
      return shoot.position.clone();
    }
    // Fallback: right-side fire position in HUD space.
    return Vector2(size.x * 7 / 8, size.y * 3 / 4);
  }

  @override
  void render(Canvas canvas) {
    if (!_lit) return;

    final btn = _buttonCenter();
    final label = _kind == ShootHintKind.chargeLaser ? 'CARGA LASER' : 'LASER';

    // Glow over the shoot pad.
    canvas.drawCircle(
      Offset(btn.x, btn.y),
      AimShootPad.radius,
      Paint()..color = const Color(0xCC00E5FF),
    );
    canvas.drawCircle(
      Offset(btn.x, btn.y),
      AimShootPad.radius,
      Paint()
        ..color = const Color(0xFF00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Text sits up-left of the button, rotated to follow the connector.
    const tilt = -0.55;
    final textPos = Offset(btn.x - 210, btn.y - 175);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF00FFFF),
          fontSize: 42,
          fontFamily: 'Megatrans',
          letterSpacing: 4,
          shadows: [
            Shadow(color: Colors.cyanAccent, blurRadius: 16),
            Shadow(color: Colors.cyan, blurRadius: 28),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(textPos.dx, textPos.dy);
    canvas.rotate(tilt);
    tp.paint(canvas, Offset.zero);
    canvas.restore();

    // Line from the text's lower-right toward the button's upper-left rim.
    final textEnd = Offset(
      textPos.dx + math.cos(tilt) * tp.width * 0.85,
      textPos.dy + math.sin(tilt) * tp.width * 0.85 + 8,
    );
    final rim = Offset(
      btn.x - AimShootPad.radius * 0.72,
      btn.y - AimShootPad.radius * 0.72,
    );
    canvas.drawLine(
      textEnd,
      rim,
      Paint()
        ..color = const Color(0xFF00FFFF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    if (_kind == ShootHintKind.chargeLaser) {
      _drawDemoBar(canvas, btn);
    }
  }

  void _drawDemoBar(Canvas canvas, Vector2 btn) {
    const barW = 220.0;
    const barH = 16.0;
    final origin = Offset(btn.x - barW / 2, btn.y + AimShootPad.radius + 18);
    final rect = Rect.fromLTWH(origin.dx, origin.dy, barW, barH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final fill = _chargeFill;

    if (fill > 0) {
      final fillColor = Color.lerp(
        const Color.fromARGB(231, 0, 255, 170),
        const Color.fromARGB(225, 180, 255, 255),
        fill,
      )!;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, origin.dy, barW * fill, barH),
        Paint()..color = fillColor,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color.fromARGB(180, 0, 229, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
