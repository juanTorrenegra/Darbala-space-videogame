import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/player.dart';

/// Cheap pooled smoke trail behind the ship's thruster.
///
/// No per-frame allocation: a fixed pool of [_SmokePuff] circles is created
/// once and recycled. Each puff is a single `CircleComponent` with a paint
/// alpha fade, so the whole trail costs ~18 cheap draw calls.
class ThrusterTrail extends Component {
  ThrusterTrail({required this.player});

  final Player player;

  static const int _poolSize = 18;
  static const double _emitInterval = 0.045;
  static const double _puffLife = 0.55;

  final Random _rng = Random();
  final List<_SmokePuff> _pool = [];
  double _emitTimer = 0;

  @override
  Future<void> onLoad() async {
    // Puffs live in the world (the parent, `universo`) so they stay behind
    // as the ship moves away, instead of following the ship.
    for (var i = 0; i < _poolSize; i++) {
      final puff = _SmokePuff(priority: player.priority - 1);
      _pool.add(puff);
      await parent?.add(puff);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (player.velocity.length2 < 4) {
      _emitTimer = 0;
      return;
    }
    _emitTimer -= dt;
    if (_emitTimer <= 0) {
      _emitTimer = _emitInterval;
      _emit();
    }
  }

  void _emit() {
    var puff = _pool.firstWhere(
      (p) => !p.isActive,
      orElse: () => _pool[_rng.nextInt(_pool.length)],
    );

    // Engine sits at the back of the ship, opposite its facing direction.
    // Facing follows `angle` with the same -pi/2 sprite offset the Player uses.
    final facing = Vector2(
      cos(player.angle + pi / 2),
      sin(player.angle + pi / 2),
    );
    final engine = player.position - facing * (player.size.x * 0.55);

    // Smoke drifts opposite to motion plus a small random spread.
    final drift = player.velocity.clone()
      ..scale(-0.18)
      ..add(
        Vector2(
          (_rng.nextDouble() - 0.5) * 8,
          (_rng.nextDouble() - 0.5) * 8,
        ),
      );

    puff.reset(
      at: engine,
      drift: drift,
      life: _puffLife * (0.8 + _rng.nextDouble() * 0.4),
      baseRadius: 2.0 + _rng.nextDouble() * 1.4,
    );
  }

  /// Extinguish every puff (used on player reset / death).
  void clear() {
    for (final puff in _pool) {
      puff.isActive = false;
    }
  }
}

class _SmokePuff extends CircleComponent {
  _SmokePuff({required int priority})
    : super(
        radius: 0,
        anchor: Anchor.center,
        priority: priority,
        paint: Paint()..color = Colors.transparent,
      );

  bool isActive = false;
  double _age = 0;
  double _life = 1;
  double _baseRadius = 2;
  final Vector2 _drift = Vector2.zero();

  void reset({
    required Vector2 at,
    required Vector2 drift,
    required double life,
    required double baseRadius,
  }) {
    isActive = true;
    _age = 0;
    _life = life;
    _baseRadius = baseRadius;
    _drift.setFrom(drift);
    position.setFrom(at);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isActive) return;
    _age += dt;
    final t = (_age / _life).clamp(0.0, 1.0);
    if (t >= 1) {
      isActive = false;
      paint.color = Colors.transparent;
      radius = 0;
      return;
    }
    position.add(_drift * dt);
    // Smoke: starts small and bright, expands and dissolves.
    radius = _baseRadius * (0.7 + t * 1.5);
    paint.color = Colors.white.withValues(alpha: 0.5 * (1 - t));
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    super.render(canvas);
  }
}
