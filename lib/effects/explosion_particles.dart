import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

class ExplosionParticle extends CircleComponent {
  final Vector2 initialPosition;
  final Vector2 velocity;
  final double lifespan;
  double lifeTimer = 0;

  ExplosionParticle({
    required this.initialPosition,
    required this.velocity,
    required this.lifespan,
    required double size,
    required Color color,
  }) : super(
         position: initialPosition.clone(),
         radius: size / 2,
         anchor: Anchor.center,
         paint: Paint()..color = color,
       );

  @override
  void update(double dt) {
    super.update(dt);
    lifeTimer += dt;
    position += velocity * dt;

    // Efecto de desvanecimiento
    final alpha = (1 - lifeTimer / lifespan).clamp(0, 1);
    paint.color = paint.color.withAlpha(150);

    // Escala que crece y luego se reduce
    final scale = 1 + sin(lifeTimer / lifespan * pi) * 0.5;
    radius = (radius * scale).clamp(1, 10);

    if (lifeTimer >= lifespan) {
      removeFromParent();
    }
  }
}

class ExplosionEffect extends Component with HasGameReference<MyGame> {
  final Vector2 center;
  final int particleCount;
  final double explosionRadius;
  final double duration;

  ExplosionEffect({
    required this.center,
    this.particleCount = 30,
    this.explosionRadius = 150,
    this.duration = 3.0,
  });

  @override
  Future<void> onLoad() async {
    _createParticles();
  }

  void _createParticles() {
    final random = Random();

    for (var i = 0; i < particleCount; i++) {
      // Dirección aleatoria
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * explosionRadius;

      // Velocidad aleatoria
      final speed = 50 + random.nextDouble() * 150;
      final velocity = Vector2(cos(angle), sin(angle)) * speed;

      // Tamaño y color aleatorios
      final size = 3 + random.nextDouble() * 7;
      final hue = random.nextDouble() * 60; // Colores entre rojo y naranja
      final color = Color.fromARGB(
        255,
        255,
        (200 + random.nextDouble() * 55).toInt(),
        (random.nextDouble() * 100).toInt(),
      );

      final particle = ExplosionParticle(
        initialPosition: center,
        velocity: velocity,
        lifespan: duration * (0.5 + random.nextDouble() * 0.5),
        size: size,
        color: color,
      );

      add(particle);
    }
  }
}

/// Charge-like death burst: energy core, then white dots fly out to [radius]
/// (`2 ×` the enemy's larger side by default).
class SpaceExplosionEffect extends PositionComponent {
  final double radius;
  final double durationScale;
  final int rippleCount;
  final double rippleSpeed;
  final int _dotCount;

  /// When false the bright white core is skipped and the dots burst right
  /// away — tutorial targets shatter rather than detonate.
  final bool showCore;

  final Random _rng = Random();

  double _age = 0;
  final double _coreRadius;
  bool _burst = false;
  final List<double> _rippleStart = [];

  double get _coreHold => showCore ? 0.1 * durationScale : 0.0;
  double get _coreFade => 0.32 * durationScale;
  double get _dotLife => 0.5 * durationScale;

  SpaceExplosionEffect({
    required Vector2 center,
    required this.radius,
    this.durationScale = 1,
    this.rippleCount = 0,
    this.rippleSpeed = 70,
    this.showCore = true,
  }) : _dotCount = (32 + radius * 0.35).round().clamp(32, 64),
       _coreRadius = (radius * 0.11).clamp(1.8, 7.0),
       super(
         position: center.clone(),
         anchor: Anchor.center,
         priority: 1400,
       ) {
    for (var i = 0; i < rippleCount; i++) {
      _rippleStart.add(_coreHold + i * 0.28 * durationScale);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;

    if (!_burst && _age >= _coreHold) {
      _burst = true;
      _spawnDots();
    }

    final lastRippleEnd = _rippleStart.isEmpty
        ? 0.0
        : _rippleStart.last + radius / rippleSpeed + 0.2;
    if (_age > max(_coreHold + _dotLife, lastRippleEnd) && children.isEmpty) {
      removeFromParent();
    }
  }

  void _spawnDots() {
    for (var i = 0; i < _dotCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final reach = radius * (0.55 + _rng.nextDouble() * 0.45);
      add(
        _OutboundDot(
          direction: Vector2(cos(angle), sin(angle)),
          travel: reach,
          lifespan: _dotLife * (0.75 + _rng.nextDouble() * 0.35),
          startRadius: 0.7 + _rng.nextDouble() * 1.1,
        ),
      );
    }
  }

  double get _coreAlpha {
    if (_age <= _coreHold) return 1;
    return (1 - (_age - _coreHold) / _coreFade).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final a = _coreAlpha;
    if (showCore && a > 0) {
      canvas.drawCircle(
        Offset.zero,
        _coreRadius,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
    _drawRipples(canvas);
  }

  void _drawRipples(Canvas canvas) {
    if (rippleCount <= 0 || rippleSpeed <= 0) return;
    for (final start in _rippleStart) {
      final t = _age - start;
      if (t <= 0) continue;
      final r = t * rippleSpeed;
      if (r > radius * 1.05) continue;
      final fade = (1 - (r / radius).clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }
}

class _OutboundDot extends CircleComponent {
  final Vector2 _velocity;
  final double lifespan;
  final double startRadius;
  double _age = 0;

  _OutboundDot({
    required Vector2 direction,
    required double travel,
    required this.lifespan,
    required this.startRadius,
  }) : _velocity = direction * (travel / lifespan),
       super(
         radius: startRadius,
         anchor: Anchor.center,
         paint: Paint()..color = Colors.white,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.add(_velocity * dt);
    final t = (_age / lifespan).clamp(0.0, 1.0);
    paint.color = Colors.white.withValues(alpha: 1 - t);
    radius = startRadius * (1 - t * 0.4);
    if (_age >= lifespan) {
      removeFromParent();
    }
  }
}
