import 'dart:math';

import 'package:flame/components.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/player.dart';

enum SpikeState { charging, bullRush }

/// Enemy that "winds up" like a bull, then rushes in a straight line.
///
/// Behavior cycle after activation:
/// 1) charging (retreat + curved drift while slowly facing player)
/// 2) bull rush (fast straight dash toward player's sampled position)
/// 3) repeats.
class SpikeEnemy extends Enemigo {
  final int damage;

  /// Radius used by [scream] to activate nearby enemies.
  final double screamRadius;

  /// Slow movement speed during the wind-up phase.
  double chargingSpeed;

  /// Fast dash speed during the bull-rush phase.
  double bullRushSpeed;

  /// Seconds spent in wind-up phase before each rush.
  double chargeDuration;

  /// Seconds spent in rush phase before restarting wind-up.
  final double bullRushDuration;

  /// Curvature intensity during wind-up.
  /// - 0.0 = pure straight retreat
  /// - 0.2..0.6 = smooth bull-like curve
  /// - > 1.0 = aggressive side drift
  double curveStrength;

  /// Multiplier applied to rotation speed while winding up.
  double chargeTurnMultiplier;

  /// Multiplier applied to rotation speed during rush.
  double rushTurnMultiplier;

  /// Rush distance as a multiple of distance-to-player at rush start.
  double rushDistanceMultiplier;

  /// Minimum rush distance so it always overshoots the player.
  double minRushDistance;

  final Random _random = Random();

  SpikeState _state = SpikeState.charging;
  double _stateTimer = 0;
  double _curveSign = 1;

  Vector2 _lineOfSightAway = Vector2(1, 0);
  Vector2 _rushDirection = Vector2(1, 0);
  Vector2 _chargeCenter = Vector2.zero();
  double _chargeRadius = 1;
  double _chargeStartAngle = 0;
  double _rushDistanceRemaining = 0;
  bool _didHitPlayerThisRush = false;

  SpikeEnemy({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required double movementSpeed,
    required double rotationSpeed,
    required this.damage,
    int maxHitPoints = 3,
    int shield = 0,
    this.screamRadius = 220,
    this.chargeDuration = 2.0,
    this.bullRushDuration = 1.0,
    this.curveStrength = 0.35,
    this.chargeTurnMultiplier = 0.35,
    this.rushTurnMultiplier = 1.4,
    this.rushDistanceMultiplier = 2.0,
    this.minRushDistance = 220.0,
    double? chargingSpeed,
    double? bullRushSpeed,
  }) : chargingSpeed = chargingSpeed ?? movementSpeed,
       bullRushSpeed = bullRushSpeed ?? (movementSpeed * 3.0),
       super(
         sprite: sprite,
         position: position,
         size: size,
         maxHitPoints: maxHitPoints,
         shield: shield,
         movementSpeed: movementSpeed,
         rotationSpeed: rotationSpeed,
       );

  void configureBehavior({
    double? curveStrength,
    double? chargingSpeed,
    double? bullRushSpeed,
    double? chargeDuration,
    double? chargeTurnMultiplier,
    double? rushTurnMultiplier,
    double? rushDistanceMultiplier,
    double? minRushDistance,
  }) {
    if (curveStrength != null) {
      this.curveStrength = curveStrength.clamp(0.0, 2.0);
    }
    if (chargingSpeed != null) {
      this.chargingSpeed = chargingSpeed.clamp(1.0, 2000.0);
    }
    if (bullRushSpeed != null) {
      this.bullRushSpeed = bullRushSpeed.clamp(1.0, 3000.0);
    }
    if (chargeDuration != null) {
      this.chargeDuration = chargeDuration.clamp(0.2, 10.0);
    }
    if (chargeTurnMultiplier != null) {
      this.chargeTurnMultiplier = chargeTurnMultiplier.clamp(0.05, 4.0);
    }
    if (rushTurnMultiplier != null) {
      this.rushTurnMultiplier = rushTurnMultiplier.clamp(0.05, 6.0);
    }
    if (rushDistanceMultiplier != null) {
      this.rushDistanceMultiplier = rushDistanceMultiplier.clamp(1.0, 8.0);
    }
    if (minRushDistance != null) {
      this.minRushDistance = minRushDistance.clamp(20.0, 4000.0);
    }
  }

  @override
  void onActivate() {
    scream();
    _beginCharging();
  }

  @override
  void onDeactivate() {
    _stateTimer = 0;
  }

  /// Activates nearby enemies that extend [Enemigo].
  void scream() {
    if (!isMounted) return;

    int activated = 0;
    for (final enemy in game.universo.children.whereType<Enemigo>()) {
      if (enemy == this || !enemy.isMounted || enemy.isActivated) continue;
      if (enemy.position.distanceTo(position) <= screamRadius) {
        enemy.activate();
        activated++;
      }
    }

    print('📣 SpikeEnemy scream -> activated $activated nearby enemies');
  }

  @override
  void onUpdateBehavior(double dt) {
    if (!game.player.isMounted) return;

    switch (_state) {
      case SpikeState.charging:
        _updateCharging(dt);
        break;
      case SpikeState.bullRush:
        _updateBullRush(dt);
        break;
    }
  }

  void _beginCharging() {
    _state = SpikeState.charging;
    _stateTimer = 0;
    _curveSign = _random.nextBool() ? 1.0 : -1.0;
    _didHitPlayerThisRush = false;

    // Snapshot the current line-of-sight and retreat away from it.
    final toPlayer = game.player.position - position;
    if (toPlayer.length2 > 0) {
      _lineOfSightAway = (-toPlayer).normalized();
    }

    // Half-circle setup:
    // radius chosen so arc length ~= chargingSpeed * chargeDuration.
    _chargeRadius = max(
      12.0,
      (chargingSpeed * chargeDuration / pi) * (1.0 + curveStrength),
    );
    _chargeCenter = position + _lineOfSightAway * _chargeRadius;
    final startOffset = position - _chargeCenter;
    _chargeStartAngle = atan2(startOffset.y, startOffset.x);
  }

  void _beginBullRush() {
    _state = SpikeState.bullRush;
    _stateTimer = 0;

    final toPlayer = game.player.position - position;
    if (toPlayer.length2 > 0) {
      _rushDirection = toPlayer.normalized();
      final distanceToPlayer = toPlayer.length;
      _rushDistanceRemaining = max(
        minRushDistance,
        distanceToPlayer * rushDistanceMultiplier,
      );
    } else {
      _rushDistanceRemaining = minRushDistance;
    }
  }

  void _updateCharging(double dt) {
    _stateTimer += dt;

    final toPlayer = game.player.position - position;
    if (toPlayer.length2 > 0) {
      final targetAngle = atan2(toPlayer.y, toPlayer.x);
      angle = rotateTowards(targetAngle, dt * chargeTurnMultiplier);
    }

    // Semicircle motion while charging.
    final progress = (_stateTimer / chargeDuration).clamp(0.0, 1.0);
    final theta = _chargeStartAngle + (_curveSign * pi * progress);
    final arcOffset = Vector2(cos(theta), sin(theta)) * _chargeRadius;
    position = _chargeCenter + arcOffset;

    if (_stateTimer >= chargeDuration) {
      _beginBullRush();
    }
  }

  void _updateBullRush(double dt) {
    _stateTimer += dt;

    final stepDistance = min(bullRushSpeed * dt, _rushDistanceRemaining);
    position += _rushDirection * stepDistance;
    _rushDistanceRemaining -= stepDistance;

    final targetAngle = atan2(_rushDirection.y, _rushDirection.x);
    angle = rotateTowards(targetAngle, dt * rushTurnMultiplier);

    if (_rushDistanceRemaining <= 0 || _stateTimer >= bullRushDuration) {
      _beginCharging();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (!isActivated || !isMounted) return;
    if (other is! Player) return;

    if (_didHitPlayerThisRush) return;
    _didHitPlayerThisRush = true;
    other.takeDamage(40);
  }
}
