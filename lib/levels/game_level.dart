import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:juanshooter/game.dart';

/// Base class for scripted levels.
///
/// A level is a child of the game itself (not of the world), so clearing the
/// world between levels never kills the level script. Provides game-time
/// helpers for scripted sequences: [waitSeconds] and [animateZoom], both
/// driven by the update loop so they respect pause and timeScale.
abstract class GameLevel extends Component with HasGameReference<MyGame> {
  /// Shown on the title card that introduces this level.
  String get title;

  bool _cancelled = false;
  bool get cancelled => _cancelled;

  double _waitRemaining = 0;
  Completer<void>? _waitCompleter;

  double _zoomFrom = 0;
  double _zoomTo = 0;
  double _zoomElapsed = 0;
  double _zoomDuration = 1;
  Completer<void>? _zoomCompleter;

  /// Waits [seconds] of game time (respects pause and timeScale).
  Future<void> waitSeconds(double seconds) {
    _waitRemaining = seconds;
    _waitCompleter = Completer<void>();
    return _waitCompleter!.future;
  }

  /// Smoothly animates the camera zoom to [target] over [seconds].
  Future<void> animateZoom(double target, double seconds) {
    _zoomFrom = game.camara?.viewfinder.zoom ?? target;
    _zoomTo = target;
    _zoomElapsed = 0;
    _zoomDuration = seconds.clamp(0.01, 100.0);
    _zoomCompleter = Completer<void>();
    return _zoomCompleter!.future;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final wait = _waitCompleter;
    if (wait != null) {
      _waitRemaining -= dt;
      if (_waitRemaining <= 0) {
        _waitCompleter = null;
        if (!wait.isCompleted) wait.complete();
      }
    }

    final zoom = _zoomCompleter;
    if (zoom != null) {
      _zoomElapsed += dt;
      final t = (_zoomElapsed / _zoomDuration).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);
      game.setZoomDirect(_zoomFrom + (_zoomTo - _zoomFrom) * eased);
      if (t >= 1) {
        _zoomCompleter = null;
        if (!zoom.isCompleted) zoom.complete();
      }
    }
  }

  /// Stops the script: pending waits/animations complete immediately and
  /// script code should check [cancelled] after every await and return.
  void cancel() {
    _cancelled = true;
    final wait = _waitCompleter;
    _waitCompleter = null;
    if (wait != null && !wait.isCompleted) wait.complete();
    final zoom = _zoomCompleter;
    _zoomCompleter = null;
    if (zoom != null && !zoom.isCompleted) zoom.complete();
  }

  @override
  void onRemove() {
    cancel();
    super.onRemove();
  }
}
