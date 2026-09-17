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

/// Tutorial target: space-rock sprite with 20 HP.
///
/// Getting hit triggers a quick shake + white flash + floating damage number
/// (same style as enemies). Its destruction is animated (flash, scale up and
/// fade out over an explosion) and is NOT counted in the ships-destroyed
/// score — it is a practice target, not a ship.
class RockTarget extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyGame>, OffscreenTracked {
  RockTarget({
    required Vector2 position,
    required this.onDestroyed,
    this.roam,
    String? spriteFile,
  }) : _spriteFile =
           spriteFile ??
           spriteFiles[_shapeRng.nextInt(spriteFiles.length)],
       super(
         position: position,
         size: Vector2.all(34),
         anchor: Anchor.center,
         angle: _shapeRng.nextDouble() * 2 * pi,
         priority: 2,
       );

  /// Called once when the rock starts its destruction animation.
  final void Function() onDestroyed;

  /// When set, the rock slowly glides around a fixed point instead of
  /// holding its spawn position.
  final GlideRoam? roam;

  static const int maxHitPoints = 20;

  /// Tutorial rock art. The opening three rocks pick these in order;
  /// later rocks pick one at random.
  static const List<String> spriteFiles = [
    'spaceRock090px3.png',
    'spaceRock084px2.png',
    'spaceRock122px.png',
  ];

  /// Longest side in world units — about the player's size (28).
  static const double _maxSide = 34;

  final String _spriteFile;

  static final Random _shapeRng = Random();
  final Random _rng = Random();
  final Vector2 _basePosition = Vector2.zero();

  /// Displacement from bullet impacts, layered on top of the roam/spawn point.
  final Vector2 _pushOffset = Vector2.zero();
  final Vector2 _pushVelocity = Vector2.zero();

  /// Fraction of push speed shed per second.
  static const double _pushDrag = 6.0;

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
    sprite = await Sprite.load(_spriteFile);
    final src = sprite!.originalSize;
    final scale = _maxSide / max(src.x, src.y);
    size = src * scale;
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
    final speed = (18 + damage * 1.4).clamp(18.0, 90.0);
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
    if (_pushVelocity.length2 < 0.05) {
      _pushVelocity.setZero();
      return;
    }
    _pushOffset.add(_pushVelocity * dt);
    _pushVelocity.scale((1 - _pushDrag * dt).clamp(0.0, 1.0));
  }
}
