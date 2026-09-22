import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:juanshooter/components/solid_body.dart';
import 'package:juanshooter/components/target_roam.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/bullet.dart';

/// Indestructible debris: [bthingy.png] at 50–100% native size.
///
/// Drifts slowly, takes a shove and a spin from player shots, and the ship
/// cannot occupy the same space ([SolidBody]).
class SpaceRock extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyGame>, SolidBody {
  SpaceRock({
    required Sprite sprite,
    required Vector2 position,
    required double sizeScale,
    required double angle,
    required this.roam,
    double idleSpin = 0,
  }) : _idleSpin = idleSpin,
       _mass = max(sizeScale * sizeScale, 0.25),
       super(
         sprite: sprite,
         position: position,
         size: sprite.originalSize * sizeScale,
         angle: angle,
         anchor: Anchor.center,
         priority: 2,
       );

  static const String spriteFile = 'bthingy.png';

  final GlideRoam roam;
  final double _idleSpin;
  final double _mass;
  final Vector2 _basePosition = Vector2.zero();
  final Vector2 _pushOffset = Vector2.zero();
  final Vector2 _pushVelocity = Vector2.zero();
  double _impactSpin = 0;

  static const double _pushDrag = 5.5;
  static const double _spinDrag = 0.55;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _basePosition.setFrom(position);
    add(CircleHitbox()..collisionType = CollisionType.passive);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! Bullet) return;
    _applyBlast(intersectionPoints, other, other.damage);
    other.removeFromParent();
  }

  void _applyBlast(
    Set<Vector2> intersectionPoints,
    PositionComponent shot,
    int damage,
  ) {
    final hit = Vector2.zero();
    if (intersectionPoints.isNotEmpty) {
      for (final point in intersectionPoints) {
        hit.add(point);
      }
      hit.scale(1 / intersectionPoints.length);
    } else {
      hit.setFrom(shot.position);
    }

    final away = position - hit;
    if (away.length2 < 1e-6) {
      away.setFrom(position - shot.position);
    }
    if (away.length2 < 1e-6) return;
    away.normalize();

    final speed = (12 + damage * 0.9).clamp(12.0, 48.0) / _mass;
    _pushVelocity.add(away * speed);

    final offset = hit - position;
    final torque = offset.x * away.y - offset.y * away.x;
    _impactSpin += (torque * 0.045 * (1 + damage * 0.03)) / _mass;
    _impactSpin = _impactSpin.clamp(-2.8, 2.8);
  }

  @override
  void update(double dt) {
    super.update(dt);
    roam.advance(_basePosition, dt);

    if (_pushVelocity.length2 >= 0.05) {
      _pushOffset.add(_pushVelocity * dt);
      _pushVelocity.scale((1 - _pushDrag * dt).clamp(0.0, 1.0));
    } else {
      _pushVelocity.setZero();
    }

    _impactSpin *= (1 - _spinDrag * dt).clamp(0.0, 1.0);
    angle += (_idleSpin + _impactSpin) * dt;
    position.setValues(
      _basePosition.x + _pushOffset.x,
      _basePosition.y + _pushOffset.y,
    );
  }
}
