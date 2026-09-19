import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/offscreen_tracked.dart';
import 'package:juanshooter/components/solid_body.dart';
import 'package:juanshooter/components/target_health_bar.dart';
import 'package:juanshooter/components/target_roam.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/potency_bar.dart';
import 'package:juanshooter/weapons/bullet.dart';

/// Tutorial target: regenerating orb sprite with 49 HP.
///
/// Regenerates 10 HP every 0.3 s and normal shots can never take it below
/// 1 HP — the only way to destroy it is a fully charged shot (50 damage,
/// which is >= its max HP). Regular shots only trigger the flash + damage
/// number feedback. Not counted in the ships-destroyed score.
class CircleTarget extends SpriteComponent
    with
        CollisionCallbacks,
        HasGameReference<MyGame>,
        OffscreenTracked,
        SolidBody {
  CircleTarget({
    required Vector2 position,
    required this.onDestroyed,
    this.roam,
  }) : super(
         position: position,
         size: Vector2.all(_maxSide),
         anchor: Anchor.center,
         priority: 2,
       );

  /// Called once when the orb starts its destruction animation.
  final void Function() onDestroyed;

  /// When set, the orb patrols its area like an idle enemy instead of
  /// holding its spawn position.
  final PatrolRoam? roam;

  static const int maxHitPoints = 49;
  static const int regenAmount = 10;
  static const double regenInterval = 0.3;
  static const String _spriteFile = 'tutorialTarget.png';

  /// Longest side in world units — matches the old 18-radius orb (36 diameter).
  static const double _maxSide = 36;

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
    sprite = await Sprite.load(_spriteFile);
    final src = sprite!.originalSize;
    final scale = _maxSide / max(src.x, src.y);
    size = src * scale;
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
    final alpha = (1 - destroyT).clamp(0.0, 1.0);

    paint.color = Colors.white.withValues(alpha: alpha);
    paint.colorFilter = flash > 0
        ? ColorFilter.mode(
            Colors.white.withValues(alpha: flash * 0.85),
            BlendMode.srcATop,
          )
        : null;

    super.render(canvas);
  }

  @override
  void renderMarkerIcon(Canvas canvas, double diameter) {
    final src = sprite;
    if (src == null) return;
    final aspect = src.originalSize.x / src.originalSize.y;
    final iconSize = aspect >= 1
        ? Vector2(diameter, diameter / aspect)
        : Vector2(diameter * aspect, diameter);
    src.render(
      canvas,
      position: Vector2.zero(),
      size: iconSize,
      anchor: Anchor.center,
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
