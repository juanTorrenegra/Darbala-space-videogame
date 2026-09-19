import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:juanshooter/actors/player.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/bullet.dart';

class EnemyBullet extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks, ProjectileLifetimeAndCull {
  final double speed;
  final Vector2 _direction = Vector2.zero();
  final int damage;

  EnemyBullet({
    required Vector2 position,
    required double angle,
    required this.speed,
    required this.damage,
  }) : super(
         position: position,
         size: Vector2(15, 25),
         anchor: Anchor.center,
         angle: angle,
       ) {
    _direction.setValues(cos(angle), sin(angle));
  }

  @override
  Future<void> onLoad() async {
    try {
      // Usa un sprite que ya existe en tu proyecto
      sprite = await Sprite.load('enemy_bullet.png');
      add(CircleHitbox()..collisionType = CollisionType.passive);
    } catch (e) {
      print('Error loading enemy bullet sprite: $e');
      removeFromParent(); // Elimina si hay error
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += _direction * speed * dt;
    tickProjectileLifetime(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      other.takeDamage(damage);
      final dir = _direction.length2 > 0
          ? _direction.normalized()
          : Vector2(1, 0);
      other.startKnockback(dir * Player.bulletBounceDistance);
      removeFromParent();
    }
  }
}
