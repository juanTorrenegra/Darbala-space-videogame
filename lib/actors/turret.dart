import 'dart:math';

import 'package:flame/components.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/enemy_bullet.dart';
import 'package:juanshooter/utils/game_utils.dart';

//.
class Turret extends SpriteComponent with HasGameReference<MyGame> {
  final double rotationSpeed;
  final double shootInterval;
  final double bulletSpeed;
  final double shootingOffset;
  final Vector2 relativePosition;
  double _shootCooldown = 0;
  double _currentAngle = 0;

  Turret({
    required Sprite sprite,
    required this.relativePosition, // Posición relativa a la nave madre
    Vector2? size,
    this.rotationSpeed = 1.0,
    this.shootInterval = 1.5,
    this.bulletSpeed = 250,
    this.shootingOffset = 15.0,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(30, 30),
         anchor: Anchor.center,
         priority: 1,
       );

  void updateTurret(
    double dt,
    Vector2 mothershipPosition,
    double mothershipAngle,
    Vector2? targetPosition,
  ) {
    // Actualizar posición absoluta basada en la nave madre
    position = mothershipPosition + relativePosition;

    // Rotar hacia el objetivo o mantener ángulo
    if (targetPosition != null) {
      _rotateTowardsTarget(dt, targetPosition);
    } else {
      angle = mothershipAngle + _currentAngle;
    }

    // Manejar disparo.
    _handleShooting(dt);
  }

  void _rotateTowardsTarget(double dt, Vector2 targetPosition) {
    final direction = targetPosition - position;
    final targetAngle = atan2(direction.y, direction.x);
    _currentAngle = _smoothRotation(
      _currentAngle,
      targetAngle,
      rotationSpeed * dt,
    );
    angle = _currentAngle;
  }

  double _smoothRotation(double current, double target, double step) {
    final difference = (target - current) % (2 * pi);
    final adjustedDifference = difference > pi
        ? difference - 2 * pi
        : difference;

    if (adjustedDifference.abs() < step) {
      return target;
    } else {
      return current + (adjustedDifference > 0 ? step : -step);
    }
  }

  void _handleShooting(double dt) {
    if (_shootCooldown > 0) {
      _shootCooldown -= dt;
    } else {
      _shoot();
      _shootCooldown = shootInterval;
    }
  }

  void _shoot() {
    final shootPosition = calculateShootPosition(
      position,
      angle,
      size,
      shootingOffset,
    );
    final bullet = EnemyBullet(
      position: shootPosition,
      angle: angle,
      speed: bulletSpeed,
    );
    game.universo.add(bullet);
  }
}
