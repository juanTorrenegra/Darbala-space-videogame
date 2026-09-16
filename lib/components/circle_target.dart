import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/offscreen_tracked.dart';
import 'package:juanshooter/components/target_health_bar.dart';
import 'package:juanshooter/components/target_roam.dart';
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
    with CollisionCallbacks, HasGameReference<MyGame>, OffscreenTracked {
  CircleTarget({
    required Vector2 position,
    required this.onDestroyed,
    this.roam,
    double radius = 18, // about the player's size (28 diameter)
  }) : super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         priority: 2,
        paint: Paint()..color = const Color(0xFF67E8F9),
      );

  /// Called once when the orb starts its destruction animation.
  final void Function() onDestroyed;

  /// When set, the orb patrols its area like an idle enemy instead of
  /// holding its spawn position.
  final PatrolRoam? roam;

  static const Color _innerColor = Color(0xFFA5F3FC); // light cyan
  static const Color _outerColor = Color(0xFF38BDF8); // light blue
  static const Color _shadowColor = Color(0xFF9E9E9E);
  static const int maxHitPoints = 49;
  static const int regenAmount = 10;
  static const double regenInterval = 0.3;

  int get hitPoints => _hitPoints;
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
    game.universo.add(
      TargetHealthBar(
        host: this,
        currentHp: () => _hitPoints,
        maxHp: () => maxHitPoints,
        isVisible: () => !_destroying,
      ),
    );
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

  /// Debug shortcut: play the destruction animation right away.
  void destroyNow() {
    if (_destroying) return;
    _hitPoints = 0;
    _startDestruction();
  }

  void _startDestruction() {
    _destroying = true;
    game.spawnEnemyExplosion(position.clone(), size.clone(), showCore: false);
    onDestroyed();
  }

  @override
  void render(Canvas canvas) {
    final destroyT = _destroying
        ? (_destroyElapsed / _destroySeconds).clamp(0.0, 1.0)
        : 0.0;
    final flash = _destroying
        ? 1.0
        : (_flashTimer / _flashSeconds).clamp(0.0, 1.0);
    final alpha = 1 - destroyT;
    final inner = Color.lerp(_innerColor, Colors.white, flash)!;
    final outer = Color.lerp(_outerColor, Colors.white, flash)!;
    final center = Offset(size.x / 2, size.y / 2);
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);

    canvas.drawCircle(
      center.translate(2.5, 3.5),
      radius,
      Paint()
        ..color = _shadowColor.withValues(alpha: 0.55 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    _fillOrb(canvas, center, radius, bounds, inner, outer, alpha);
  }

  void _fillOrb(
    Canvas canvas,
    Offset center,
    double r,
    Rect bounds,
    Color inner,
    Color outer,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            inner.withValues(alpha: alpha),
            outer.withValues(alpha: alpha),
          ],
          radius: 0.85,
        ).createShader(bounds),
    );
  }

  @override
  void renderMarkerIcon(Canvas canvas, double diameter) {
    final r = diameter / 2;
    _fillOrb(
      canvas,
      Offset.zero,
      r,
      Rect.fromCircle(center: Offset.zero, radius: r),
      _innerColor,
      _outerColor,
      1,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_destroying) {
      _destroyElapsed += dt;
      final t = (_destroyElapsed / _destroySeconds).clamp(0.0, 1.0);
      scale = Vector2.all(1 + 0.6 * t);
      if (t >= 1) {
        removeFromParent();
      }
      return;
    }

    roam?.advance(position, dt);

    // Regenerate 10 HP every 0.3 s, up to max.
    _regenTimer += dt;
    while (_regenTimer >= regenInterval) {
      _regenTimer -= regenInterval;
      _hitPoints = min(maxHitPoints, _hitPoints + regenAmount);
    }

    if (_flashTimer > 0) {
      _flashTimer -= dt;
    }
  }
}
