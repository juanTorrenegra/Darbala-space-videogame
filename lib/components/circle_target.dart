import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/potency_bar.dart';
import 'package:juanshooter/weapons/bullet.dart';

/// Tutorial target: regenerating orb with 49 HP.
///
/// Regenerates 10 HP every 0.3 s and normal shots can never take it below
/// 1 HP — the only way to destroy it is a fully charged shot (50 damage,
/// which is >= its max HP). Regular shots only trigger the flash + damage
/// number feedback. Not counted in the ships-destroyed score.
class CircleTarget extends CircleComponent
    with CollisionCallbacks, HasGameReference<MyGame> {
  CircleTarget({
    required Vector2 position,
    required this.onDestroyed,
    double radius = 18, // about the player's size (28 diameter)
  }) : super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         priority: 2,
         paint: Paint()..color = _baseColor,
       );

  /// Called once when the orb starts its destruction animation.
  final void Function() onDestroyed;

  static const Color _baseColor = Color(0xFF3E6FB0);
  static const int maxHitPoints = 49;
  static const int regenAmount = 10;
  static const double regenInterval = 0.3;

  int _hitPoints = maxHitPoints;
  double _regenTimer = 0;
  double _flashTimer = 0;
  bool _destroying = false;
  double _destroyElapsed = 0;

  static const double _flashSeconds = 0.12;
  static const double _destroySeconds = 0.28;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
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

    // Only a fully charged shot (50 dmg >= 49 max HP) can destroy it.
    if (damage >= maxHitPoints) {
      _startDestruction();
      return;
    }

    // Regular shots: floor at 1 HP, flash + damage number only.
    _hitPoints = max(1, _hitPoints - damage);
    _flashTimer = _flashSeconds;
    game.universo.add(
      DamagePopup(
        worldPosition: position.clone() + Vector2(0, -size.y * 0.7),
        damage: damage,
      ),
    );
  }

  void _startDestruction() {
    _destroying = true;
    paint.color = Colors.white;
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

    // Regenerate 10 HP every 0.3 s, up to max.
    _regenTimer += dt;
    while (_regenTimer >= regenInterval) {
      _regenTimer -= regenInterval;
      _hitPoints = min(maxHitPoints, _hitPoints + regenAmount);
    }

    if (_flashTimer > 0) {
      _flashTimer -= dt;
      final f = (_flashTimer / _flashSeconds).clamp(0.0, 1.0);
      paint.color = Color.lerp(_baseColor, Colors.white, f)!;
    }
  }
}
