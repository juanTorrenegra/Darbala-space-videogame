import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/potency_bar.dart';
import 'package:juanshooter/weapons/bullet.dart';

/// Tutorial target: asymmetric rock-shaped polygon with 20 HP.
///
/// Getting hit triggers a quick shake + white flash + floating damage number
/// (same style as enemies). Its destruction is animated (flash, scale up and
/// fade out over an explosion) and is NOT counted in the ships-destroyed
/// score — it is a practice target, not a ship.
class RockTarget extends PolygonComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  RockTarget({required Vector2 position, required this.onDestroyed})
    : super(
        _vertices,
        position: position,
        size: Vector2.all(34), // about the player's size (28)
        anchor: Anchor.center,
        priority: 2,
        paint: Paint()..color = _baseColor,
      );

  /// Called once when the rock starts its destruction animation.
  final void Function() onDestroyed;

  static const Color _baseColor = Color(0xFF8D7B6D);
  static const int maxHitPoints = 20;

  /// Asymmetric boulder outline in local space (0..34 box).
  static final List<Vector2> _vertices = [
    Vector2(32, 15),
    Vector2(24, 3),
    Vector2(12, 1),
    Vector2(1, 11),
    Vector2(5, 27),
    Vector2(17, 33),
    Vector2(30, 25),
  ];

  final Random _rng = Random();
  final Vector2 _basePosition = Vector2.zero();

  int _hitPoints = maxHitPoints;
  double _flashTimer = 0;
  double _shakeTimer = 0;
  bool _destroying = false;
  double _destroyElapsed = 0;

  static const double _flashSeconds = 0.12;
  static const double _shakeSeconds = 0.18;
  static const double _destroySeconds = 0.28;

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
    if (other is! Bullet || _destroying) return;

    final damage = other.damage;
    other.removeFromParent();
    _hitPoints -= damage;
    _flashTimer = _flashSeconds;
    _shakeTimer = _shakeSeconds;

    game.universo.add(
      DamagePopup(
        worldPosition: position.clone() + Vector2(0, -size.y * 0.7),
        damage: damage,
      ),
    );

    if (_hitPoints <= 0) {
      _startDestruction();
    }
  }

  void _startDestruction() {
    _destroying = true;
    paint.color = Colors.white;
    // Explosion + sfx, but no score: rocks are not ships.
    game.spawnEnemyExplosion(position.clone(), size.clone());
    onDestroyed();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_destroying) {
      _destroyElapsed += dt;
      final t = (_destroyElapsed / _destroySeconds).clamp(0.0, 1.0);
      scale = Vector2.all(1 + 0.6 * t);
      paint.color = Colors.white.withValues(alpha: 1 - t);
      if (t >= 1) {
        removeFromParent();
      }
      return;
    }

    if (_flashTimer > 0) {
      _flashTimer -= dt;
      final f = (_flashTimer / _flashSeconds).clamp(0.0, 1.0);
      paint.color = Color.lerp(_baseColor, Colors.white, f)!;
    }

    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      if (_shakeTimer <= 0) {
        position.setFrom(_basePosition);
      } else {
        position.setValues(
          _basePosition.x + (_rng.nextDouble() - 0.5) * 3,
          _basePosition.y + (_rng.nextDouble() - 0.5) * 3,
        );
      }
    }
  }
}
