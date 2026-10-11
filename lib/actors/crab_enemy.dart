import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/components/facing_frames.dart';

/// Melee crab: patrols [patrolRadius] while idle, then chases and slashes
/// once the player enters [alarmRadius] or it takes damage.
class CrabEnemy extends Enemigo {
  final int damage;

  /// Extra claw reach beyond the two hull radii.
  final double meleeRange;
  final double knockbackDistance;
  final double patrolRadius;

  bool _slashOnCooldown = false;
  double _slashCooldownTimer = 0;
  final Vector2 _knockbackRemaining = Vector2.zero();
  final Vector2 velocity = Vector2.zero();
  final Vector2 _patrolOrigin;
  final Vector2 _patrolTarget = Vector2.zero();
  final Random _rng = Random();

  /// Seconds to reach [movementSpeed] from a standstill.
  double accelTime = 2.0;

  /// Seconds to coast to a stop after cutting thrust.
  double coastTime = 1.2;

  double _logicalAngle = 0;

  CrabEnemy({
    required Vector2 position,
    Vector2? size,
    double angle = 0,
    int maxHitPoints = 50,
    int shield = 0,
    double movementSpeed = 25,
    double rotationSpeed = 4.0,
    this.damage = 20,
    double alarmRadius = 100,
    this.meleeRange = 8,
    this.knockbackDistance = 30,
    this.patrolRadius = 100,
  }) : _patrolOrigin = position.clone(),
       _logicalAngle = angle,
       super(
         position: position,
         size: size ?? Vector2(30, 30),
         angle: 0,
         maxHitPoints: maxHitPoints,
         shield: shield,
         movementSpeed: movementSpeed,
         rotationSpeed: rotationSpeed,
         alarmRadius: alarmRadius,
       ) {
    _pickPatrolTarget();
  }

  @override
  double get angle => _logicalAngle;

  @override
  set angle(double a) {
    _logicalAngle = a;
    _syncFacingSprite();
  }

  void _syncFacingSprite() {
    final ticker = animationTicker;
    if (ticker == null) return;
    ticker.currentIndex = FacingFrames.indexForAngle(_logicalAngle);
  }

  @override
  Future<void> onLoad() async {
    await applyCrabSkin(game.crabSkinSlot);
    await super.onLoad();
  }

  Future<void> applyCrabSkin(int slot) async {
    final loaded = await FacingFrames.enemyAnimation(slot);
    if (loaded == null) return;
    game.crabSkinSlot = slot;
    animation = loaded;
    playing = false;
    _syncFacingSprite();
  }

  @override
  void onDeactivate() {
    _slashOnCooldown = false;
    _slashCooldownTimer = 0;
    _knockbackRemaining.setZero();
    velocity.setZero();
  }

  void _updateKnockback(double dt) {
    if (_knockbackRemaining.length2 < 1e-8) return;
    final remaining = _knockbackRemaining.length;
    final step = game.knockbackSpeed * dt;
    if (step >= remaining) {
      position.add(_knockbackRemaining);
      _knockbackRemaining.setZero();
      return;
    }
    final dir = _knockbackRemaining.normalized();
    position.add(dir * step);
    _knockbackRemaining.scale((remaining - step) / remaining);
  }

  void _steerVelocityToward(Vector2 target, double rate, double dt) {
    final delta = target - velocity;
    final distance = delta.length;
    final maxStep = rate * dt;
    if (distance <= maxStep) {
      velocity.setFrom(target);
      return;
    }
    velocity.add(delta.normalized() * maxStep);
  }

  void _updateSpaceMovement(
    double dt, {
    required bool thrusting,
    Vector2? thrustDir,
    double? speed,
  }) {
    final maxSpeed = (speed ?? movementSpeed).clamp(1.0, 10000.0);
    if (thrusting && thrustDir != null && thrustDir.length2 > 0.0001) {
      final accel = maxSpeed / accelTime.clamp(0.05, 20.0);
      _steerVelocityToward(thrustDir.normalized() * maxSpeed, accel, dt);
    } else {
      final decel = maxSpeed / coastTime.clamp(0.05, 30.0);
      _steerVelocityToward(Vector2.zero(), decel, dt);
    }
    if (velocity.length > maxSpeed) {
      velocity.scale(maxSpeed / velocity.length);
    }
    if (velocity.length2 > 1e-8) {
      position.add(velocity * dt);
    }
  }

  /// Center-to-center distance where claws can hit: hulls touching, plus
  /// [meleeRange] extra reach. Scales with the player's current size.
  double _slashDistance() {
    return game.player.bodyRadius + bodyRadius + meleeRange;
  }

  void _pickPatrolTarget() {
    for (var i = 0; i < 8; i++) {
      final r = sqrt(_rng.nextDouble()) * patrolRadius;
      final theta = _rng.nextDouble() * 2 * pi;
      _patrolTarget.setValues(
        _patrolOrigin.x + cos(theta) * r,
        _patrolOrigin.y + sin(theta) * r,
      );
      if (_patrolTarget.distanceTo(position) > patrolRadius * 0.3) {
        return;
      }
    }
  }

  void _containInPatrolArea() {
    final offset = position - _patrolOrigin;
    final dist = offset.length;
    // Inertia overshoot only — if they were chasing far away, steer back
    // via waypoints instead of snapping.
    if (dist <= patrolRadius || dist > patrolRadius + 8) return;
    final outward = offset / dist;
    position.setFrom(_patrolOrigin + outward * patrolRadius);
    final outwardSpeed = velocity.dot(outward);
    if (outwardSpeed > 0) {
      velocity.add(outward * -outwardSpeed);
    }
    _pickPatrolTarget();
  }

  @override
  void onIdleBehavior(double dt) {
    final toTarget = _patrolTarget - position;
    if (toTarget.length < 12) {
      _pickPatrolTarget();
    }
    final toNew = _patrolTarget - position;
    if (toNew.length2 > 0) {
      angle = rotateTowards(atan2(toNew.y, toNew.x), dt);
      _updateSpaceMovement(
        dt,
        thrusting: true,
        thrustDir: toNew,
        speed: movementSpeed * 0.5,
      );
    }
    _containInPatrolArea();
  }

  @override
  void onUpdateBehavior(double dt) {
    if (!game.player.isMounted) return;

    _updateKnockback(dt);

    if (_slashOnCooldown) {
      _slashCooldownTimer -= dt;
      if (_slashCooldownTimer <= 0) {
        _slashOnCooldown = false;
        _slashCooldownTimer = 0;
        velocity.setZero();
      } else {
        final toPlayer = game.player.position - position;
        if (toPlayer.length2 > 0) {
          angle = rotateTowards(atan2(toPlayer.y, toPlayer.x), dt);
        }
        return;
      }
    }

    final toPlayer = game.player.position - position;
    final distance = toPlayer.length;

    if (toPlayer.length2 > 0) {
      angle = rotateTowards(atan2(toPlayer.y, toPlayer.x), dt);
    }

    final slashDistance = _slashDistance();
    _updateSpaceMovement(
      dt,
      thrusting: distance > slashDistance,
      thrustDir: toPlayer,
    );

    // Re-measure after closing the gap so arriving this frame still attacks.
    // Epsilon covers float error from stopping exactly on the range circle.
    final toPlayerNow = game.player.position - position;
    if (toPlayerNow.length <= slashDistance + 1 &&
        !game.player.isInvulnerable) {
      _slash(toPlayerNow);
    }
  }

  void _slash(Vector2 toPlayer) {
    final player = game.player;

    _slashOnCooldown = true;
    _slashCooldownTimer = 1.0;
    velocity.setZero();

    final slashAngle = toPlayer.length2 > 0
        ? atan2(toPlayer.y, toPlayer.x)
        : angle;
    final midpoint = (position + player.position) / 2;
    game.universo.add(
      SlashHitEffect(worldPosition: midpoint, angle: slashAngle + pi / 4),
    );

    player.takeDamage(damage);

    final away = player.position - position;
    final dir = away.length2 > 0 ? away.normalized() : Vector2(1, 0);
    game.applyPlayerKnockback(dir * knockbackDistance);
    _knockbackRemaining.setFrom(-dir * knockbackDistance);
  }
}

/// Three diagonal curved white slashes that flash for [lifetime] seconds.
class SlashHitEffect extends PositionComponent {
  static const double lifetime = 0.8;

  double _elapsed = 0;

  SlashHitEffect({required Vector2 worldPosition, required double angle})
    : super(
        position: worldPosition,
        size: Vector2(48, 48),
        angle: angle,
        anchor: Anchor.center,
        priority: 1500,
      );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final flash = 0.55 + 0.45 * sin(_elapsed * pi * 10).abs();
    final opacity = ((1 - t) * flash).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.translate(size.x / 2, size.y / 2);
    for (var i = 0; i < 3; i++) {
      final offset = -12.0 + i * 12.0;
      _drawPointySlash(
        canvas,
        paint,
        Vector2(offset - 10, -18),
        Vector2(offset + 6, -2),
        Vector2(offset + 16, 18),
      );
    }
  }

  /// Filled ribbon along a quadratic curve, width 0 at the tips.
  void _drawPointySlash(
    Canvas canvas,
    Paint paint,
    Vector2 p0,
    Vector2 p1,
    Vector2 p2,
  ) {
    const samples = 14;
    const maxHalfWidth = 1.35;
    final left = <Offset>[];
    final right = <Offset>[];

    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final point = _quadPoint(p0, p1, p2, t);
      final tangent = _quadTangent(p0, p1, p2, t);
      if (tangent.length2 < 1e-8) continue;
      tangent.normalize();
      final normal = Vector2(-tangent.y, tangent.x);
      final halfWidth = maxHalfWidth * sin(pi * t);
      left.add(
        Offset(point.x + normal.x * halfWidth, point.y + normal.y * halfWidth),
      );
      right.add(
        Offset(point.x - normal.x * halfWidth, point.y - normal.y * halfWidth),
      );
    }

    if (left.length < 2) return;
    canvas.drawPath(
      Path()..addPolygon([...left, ...right.reversed], true),
      paint,
    );
  }

  Vector2 _quadPoint(Vector2 p0, Vector2 p1, Vector2 p2, double t) {
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  Vector2 _quadTangent(Vector2 p0, Vector2 p1, Vector2 p2, double t) {
    return (p1 - p0) * (2 * (1 - t)) + (p2 - p1) * (2 * t);
  }
}
