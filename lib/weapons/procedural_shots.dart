import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/bullet.dart';

/// Tiny filled circle. One draw call, shared paints, no trail — cheap to spam.
class NeedleShot extends PositionComponent
    with HasGameReference<MyGame>, ProjectileLifetimeAndCull, PlayerProjectile {
  static final Paint _fill = Paint()
    ..color = const Color(0xFFEAF4FF)
    ..style = PaintingStyle.fill;

  final double speed;
  @override
  final int damage;
  final Vector2 _direction = Vector2.zero();

  NeedleShot({
    required Vector2 position,
    required double angle,
    required this.speed,
    required this.damage,
    double sizeScale = 1,
  }) : super(
         position: position,
         size: Vector2.all(7) * sizeScale,
         anchor: Anchor.center,
       ) {
    _direction.setValues(cos(angle), sin(angle));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(_direction, speed * dt);
    tickProjectileLifetime(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!isProjectileVisible) return;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, _fill);
  }
}

/// Magenta bolt with a soft halo and a fading position trail.
class PlasmaBolt extends PositionComponent
    with HasGameReference<MyGame>, ProjectileLifetimeAndCull, PlayerProjectile {
  static const int _trailCap = 12;
  static const double _emitEvery = 0.016;

  final double speed;
  @override
  final int damage;
  final Vector2 _direction = Vector2.zero();
  final List<Vector2> _trail = List.generate(_trailCap, (_) => Vector2.zero());
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  int _head = 0;
  int _len = 0;
  double _emitAcc = 0;

  PlasmaBolt({
    required Vector2 position,
    required double angle,
    required this.speed,
    required this.damage,
    double sizeScale = 1,
  }) : super(
         position: position,
         size: Vector2(18, 12) * sizeScale,
         anchor: Anchor.center,
       ) {
    _direction.setValues(cos(angle), sin(angle));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(_direction, speed * dt);
    tickProjectileLifetime(dt);

    _emitAcc += dt;
    if (_emitAcc >= _emitEvery) {
      _emitAcc = 0;
      _trail[_head].setFrom(position);
      _head = (_head + 1) % _trailCap;
      if (_len < _trailCap) _len++;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isProjectileVisible) return;
    final cx = size.x / 2;
    final cy = size.y / 2;

    for (var i = 0; i < _len; i++) {
      final idx = (_head - _len + i + _trailCap) % _trailCap;
      final t = (i + 1) / (_len + 1);
      final wx = _trail[idx].x - position.x;
      final wy = _trail[idx].y - position.y;
      final r = (1.2 + 3.6 * t) * (size.x / 18);
      _paint.color = Color.fromARGB((t * 150).toInt(), 210, 70, 255);
      canvas.drawCircle(Offset(cx + wx, cy + wy), r, _paint);
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(atan2(_direction.y, _direction.x));

    _paint.color = const Color(0x55E060FF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x * 1.35,
        height: size.y,
      ),
      _paint,
    );
    _paint.color = const Color(0x88FF9CFF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x * 0.85,
        height: size.y * 0.5,
      ),
      _paint,
    );
    _paint.color = const Color(0xFFF5E9FF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x * 0.42,
        height: size.y * 0.22,
      ),
      _paint,
    );
    canvas.restore();
  }
}

/// Hollow gold disc with a spinning dashed rim. Distinct silhouette,
/// no history buffer, a few cheap stroke draws.
class IonRing extends PositionComponent
    with HasGameReference<MyGame>, ProjectileLifetimeAndCull, PlayerProjectile {
  static const int _ticks = 8;

  static final Paint _glow = Paint()
    ..color = const Color(0x44FFB020)
    ..style = PaintingStyle.fill;
  static final Paint _core = Paint()
    ..color = const Color(0xCCFFE8A0)
    ..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..color = const Color(0xFFFFC94A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  final double speed;
  @override
  final int damage;
  final Vector2 _direction = Vector2.zero();
  double _spin = 0;
  double _pulse = 0;

  IonRing({
    required Vector2 position,
    required double angle,
    required this.speed,
    required this.damage,
    double sizeScale = 1,
  }) : super(
         position: position,
         size: Vector2.all(16) * sizeScale,
         anchor: Anchor.center,
       ) {
    _direction.setValues(cos(angle), sin(angle));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(_direction, speed * dt);
    _spin += dt * 9;
    _pulse += dt * 7;
    tickProjectileLifetime(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!isProjectileVisible) return;
    final c = Offset(size.x / 2, size.y / 2);
    final pulse = 0.88 + 0.12 * sin(_pulse);
    final r = size.x * 0.42 * pulse;

    canvas.drawCircle(c, r * 1.45, _glow);
    canvas.drawCircle(c, r * 0.22, _core);

    _stroke.strokeWidth = 1.6 * (size.x / 16);
    canvas.drawCircle(c, r, _stroke);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_spin);
    final tickInner = r * 0.62;
    final tickOuter = r * 1.12;
    for (var i = 0; i < _ticks; i++) {
      final a = i * (2 * pi / _ticks);
      canvas.drawLine(
        Offset(cos(a) * tickInner, sin(a) * tickInner),
        Offset(cos(a) * tickOuter, sin(a) * tickOuter),
        _stroke,
      );
    }
    canvas.restore();
  }
}
