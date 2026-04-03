import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/weapons/bullet.dart';

abstract class Enemigo extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  int hitPoints;
  final int maxHitPoints;
  final int shield;
  final double movementSpeed;
  final double rotationSpeed;
  bool _isActivated = false;

  Enemigo({
    required Sprite sprite,
    required Vector2 position,
    Vector2? size,
    double angle = 0, // ✅ Ángulo inicial personalizable
    int maxHitPoints = 3,
    this.shield = 0,
    this.movementSpeed = 0,
    this.rotationSpeed = 1.0, // ✅ Velocidad de rotación base
  }) : hitPoints = maxHitPoints,
       maxHitPoints = maxHitPoints,
       super(
         position: position,
         size: size ?? Vector2.all(60),
         anchor: Anchor.center,
         angle: angle, // ✅ Usa el ángulo proporcionado
         sprite: sprite,
       );

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isActivated) {
      onUpdateBehavior(dt);
    }
  }

  void onUpdateBehavior(double dt);

  void activate() {
    _isActivated = true;
    onActivate();
  }

  void deactivate() {
    _isActivated = false;
  } // creada por mi para intentar desactivar, borrar?

  // Método opcional para comportamiento al activarse
  void onActivate() {} //dame un ejemplo de como usar y por que este metodo

  //  Método para rotar suavemente hacia un ángulo objetivo
  double rotateTowards(double targetAngle, double dt) {
    return _smoothRotation(angle, targetAngle, rotationSpeed * dt);
  }

  //  Método para normalizar ángulos (útil para todas las subclases)
  double _normalizeAngle(double angle) {
    angle = angle % (2 * pi);
    if (angle > pi) angle -= 2 * pi;
    if (angle < -pi) angle += 2 * pi;
    return angle;
  }

  //  Método para rotación suave (útil para todas las subclases)
  double _smoothRotation(double currentAngle, double targetAngle, double t) {
    currentAngle = _normalizeAngle(currentAngle);
    targetAngle = _normalizeAngle(targetAngle);

    double difference = targetAngle - currentAngle;

    if (difference > pi) difference -= 2 * pi;
    if (difference < -pi) difference += 2 * pi;

    return currentAngle + difference * t;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Bullet) {
      _takeDamage(1);
      other.removeFromParent();

      if (!_isActivated) {
        activate();
      }
    }
  }

  void _takeDamage(int damage) {
    final remainingShield = shield - damage;
    if (remainingShield >= 0) {
      // TODO: Efecto visual de escudo hacer
      return;
    }

    hitPoints += remainingShield;

    if (hitPoints <= 0) {
      removeFromParent();
      onDeath();
    }
  }

  void onDeath() {
    game.incrementShipsDestroyed();
  }
}
