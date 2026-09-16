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

/// Tutorial target: asymmetric rock-shaped polygon with 20 HP.
///
/// Getting hit triggers a quick shake + white flash + floating damage number
/// (same style as enemies). Its destruction is animated (flash, scale up and
/// fade out over an explosion) and is NOT counted in the ships-destroyed
/// score — it is a practice target, not a ship.
class RockTarget extends PolygonComponent
    with CollisionCallbacks, HasGameReference<MyGame>, OffscreenTracked {
  RockTarget({
    required Vector2 position,
    required this.onDestroyed,
    this.roam,
    this.curved = false,
  }) : super(
         _vertices,
         position: position,
         size: Vector2.all(34), // about the player's size (28)
         anchor: Anchor.center,
         angle: _shapeRng.nextDouble() * 2 * pi,
         priority: 2,
         paint: Paint()..color = const Color(0xFF1D4ED8),
       );

  /// Called once when the rock starts its destruction animation.
  final void Function() onDestroyed;

  /// When set, the rock slowly glides around a fixed point instead of
  /// holding its spawn position.
  final GlideRoam? roam;

  /// When true, one random corner's two straight edges are drawn as a single
  /// outward curve, so the rocks are not all flat-sided.
  final bool curved;

  static const Color _innerColor = Color.fromARGB(219, 94, 97, 146); // cyan
  static const Color _outerColor = Color.fromARGB(214, 131, 140, 165); // blue
  static const Color _shadowColor = Color.fromARGB(223, 42, 174, 146);
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

  /// Drives spawn-time variety (facing, curved corner) from the constructor,
  /// before instance fields exist.
  static final Random _shapeRng = Random();

  /// Corner whose two edges become a curve. Never the first vertex, so the
  /// curve never wraps across the path's start point.
  late final int? _curveCorner = curved
      ? 1 + _shapeRng.nextInt(_vertices.length - 2)
      : null;

  /// How far past the corner the curve's control point sits.
  static const double _curveBulge = 1.55;

  final Random _rng = Random();
  final Vector2 _basePosition = Vector2.zero();

  /// Displacement from bullet impacts, layered on top of the roam/spawn point.
  final Vector2 _pushOffset = Vector2.zero();
  final Vector2 _pushVelocity = Vector2.zero();

  /// Fraction of push speed shed per second.
  static const double _pushDrag = 6.0;

  /// Impact kick is scaled right down so hits nudge instead of shoving.
  static const double _pushSpeedScale = 0.2;

  /// Only half the drift distance is kept.
  static const double _pushOffsetScale = 0.5;

  int get hitPoints => _hitPoints;
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
    _applyPush(intersectionPoints, other, damage);
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

  /// Nudges the rock away from where the shot landed, harder for charged shots.
  void _applyPush(
    Set<Vector2> intersectionPoints,
    PositionComponent shot,
    int damage,
  ) {
    final away = Vector2.zero();
    if (intersectionPoints.isNotEmpty) {
      for (final point in intersectionPoints) {
        away.add(position - point);
      }
    } else {
      away.setFrom(position - shot.position);
    }
    if (away.length2 < 1e-6) return;
    final speed = (18 + damage * 1.4).clamp(18.0, 90.0) * _pushSpeedScale;
    _pushVelocity.add(away.normalized() * speed);
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

  Path get _shapePath {
    final verts = vertices;
    final count = verts.length;
    final corner = _curveCorner;
    final path = Path()..moveTo(verts.first.x, verts.first.y);
    var i = 0;
    while (i < count) {
      final next = (i + 1) % count;
      if (next == corner) {
        // Replace the two edges meeting at this corner with one bulge that
        // leans outward from the rock's center.
        final pivot = verts[corner!];
        final after = verts[(corner + 1) % count];
        final control =
            Vector2(size.x / 2, size.y / 2) +
            (pivot - Vector2(size.x / 2, size.y / 2)) * _curveBulge;
        path.quadraticBezierTo(control.x, control.y, after.x, after.y);
        i += 2;
        continue;
      }
      path.lineTo(verts[next].x, verts[next].y);
      i++;
    }
    path.close();
    return path;
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
    final path = _shapePath;
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);

    canvas.save();
    canvas.translate(2.5, 3.5);
    canvas.drawPath(
      path,
      Paint()
        ..color = _shadowColor.withValues(alpha: 0.55 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();

    _fillShape(canvas, path, bounds, inner, outer, alpha);
  }

  void _fillShape(
    Canvas canvas,
    Path path,
    Rect bounds,
    Color inner,
    Color outer,
    double alpha,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            inner.withValues(alpha: alpha),
            outer.withValues(alpha: alpha),
          ],
          radius: 0.9,
        ).createShader(bounds),
    );
  }

  @override
  void renderMarkerIcon(Canvas canvas, double diameter) {
    canvas.save();
    canvas.scale(diameter / max(size.x, size.y));
    canvas.translate(-size.x / 2, -size.y / 2);
    _fillShape(
      canvas,
      _shapePath,
      Rect.fromLTWH(0, 0, size.x, size.y),
      _innerColor,
      _outerColor,
      1,
    );
    canvas.restore();
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

    if (_flashTimer > 0) {
      _flashTimer -= dt;
    }

    roam?.advance(_basePosition, dt);
    _updatePush(dt);

    var x = _basePosition.x + _pushOffset.x;
    var y = _basePosition.y + _pushOffset.y;
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      if (_shakeTimer > 0) {
        x += (_rng.nextDouble() - 0.5) * 3;
        y += (_rng.nextDouble() - 0.5) * 3;
      }
    }
    position.setValues(x, y);
  }

  void _updatePush(double dt) {
    if (_pushVelocity.length2 < 0.01) {
      _pushVelocity.setZero();
      return;
    }
    _pushOffset.add(_pushVelocity * (dt * _pushOffsetScale));
    _pushVelocity.scale((1 - _pushDrag * dt).clamp(0.0, 1.0));
  }
}
