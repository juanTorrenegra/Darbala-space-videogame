import 'dart:math';

import 'package:flame/components.dart';

/// Slow orbital drift around a fixed point. Used by the tutorial rocks so they
/// glide gently around the center of their background tile.
class GlideRoam {
  GlideRoam({
    required Vector2 center,
    this.radius = 90,
    this.angularSpeed = 0.22,
    double phase = 0,
  }) : _center = center.clone(),
       _angle = phase;

  final Vector2 _center;
  final double radius;

  /// Radians per second; 0.22 is a full lap every ~28 s.
  final double angularSpeed;

  double _angle;

  /// Advances the orbit and writes the new point into [out].
  void advance(Vector2 out, double dt) {
    _angle += angularSpeed * dt;
    out.setValues(
      _center.x + cos(_angle) * radius,
      _center.y + sin(_angle) * radius * 0.7,
    );
  }

  Vector2 get startPoint =>
      Vector2(_center.x + cos(_angle) * radius, _center.y + sin(_angle) * radius * 0.7);
}

/// Waypoint patrol inside a circle, matching the idle crab enemy: pick a random
/// point in range, steer toward it with inertia, pick a new one on arrival.
class PatrolRoam {
  PatrolRoam({
    required Vector2 origin,
    this.radius = 126,
    this.speed = 12.5,
  }) : _origin = origin.clone() {
    _pickTarget();
  }

  final Vector2 _origin;
  final double radius;

  /// World units per second; the crab patrols at `movementSpeed * 0.5` = 12.5.
  final double speed;

  /// Seconds to reach [speed] from a standstill.
  final double accelTime = 2.0;

  final Vector2 velocity = Vector2.zero();
  final Vector2 _target = Vector2.zero();
  final Random _rng = Random();

  void _pickTarget() {
    for (var i = 0; i < 8; i++) {
      final r = sqrt(_rng.nextDouble()) * radius;
      final theta = _rng.nextDouble() * 2 * pi;
      _target.setValues(
        _origin.x + cos(theta) * r,
        _origin.y + sin(theta) * r,
      );
      if (_target.distanceTo(_origin) > radius * 0.3) return;
    }
  }

  /// Steers [position] toward the current waypoint and moves it.
  void advance(Vector2 position, double dt) {
    if (_target.distanceTo(position) < 12) {
      _pickTarget();
    }
    final toTarget = _target - position;
    if (toTarget.length2 <= 0) return;

    final desired = toTarget.normalized() * speed;
    final accel = speed / accelTime;
    final delta = desired - velocity;
    final maxStep = accel * dt;
    if (delta.length <= maxStep) {
      velocity.setFrom(desired);
    } else {
      velocity.add(delta.normalized() * maxStep);
    }
    position.add(velocity * dt);

    // Inertia overshoot: pull back to the patrol circle.
    final offset = position - _origin;
    if (offset.length > radius) {
      position.setFrom(_origin + offset.normalized() * radius);
      _pickTarget();
    }
  }
}
