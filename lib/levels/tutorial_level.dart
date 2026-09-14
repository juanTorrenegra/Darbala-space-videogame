import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:juanshooter/components/circle_target.dart';
import 'package:juanshooter/components/rock_target.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/levels/game_level.dart';
import 'package:juanshooter/levels/sector_level.dart';

/// Level 0 — shooting tutorial.
///
/// The ship sits static on the right side of the view; the movement stick
/// only aims, clamped to a 180° cone facing right (no aiming backwards).
///
/// Script:
/// 1. Zoom 3.5 — destroy 3 rocks (20 HP each).
/// 2. Wait 2 s — zoom animates 3.5 → 2.2 over 3 s.
/// 3. One regenerating orb (49 HP, +10 HP / 0.3 s, min 1 HP) — only a fully
///    charged shot (50 dmg) destroys it.
/// 4. Wait 2 s — zoom animates 2.2 → 1.8 over 3 s.
/// 5. Three orbs — same charge-to-destroy rule.
/// 6. Wait 1 s — "SECTOR 7" title card (blur, glitches, black), then the
///    first real level loads behind the black screen.
class TutorialLevel extends GameLevel {
  /// Camera zoom for each phase of the tutorial.
  static const double rocksZoom = 3.5;
  static const double circleZoom = 2.2;
  static const double circlesZoom = 1.8;

  /// Where the static ship sits for the whole tutorial.
  static final Vector2 playerPosition = Vector2(380, 380);

  /// How far across the view the ship sits (0.65 = 65% from the left).
  static const double playerScreenFraction = 0.65;

  int _rocksDestroyed = 0;
  Completer<void>? _rocksCompleter;
  Completer<void>? _circleCompleter;
  int _circlesDestroyed = 0;
  Completer<void>? _circlesCompleter;

  @override
  String get title => 'TUTORIAL';

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final player = game.player;
    player.staticAimOnly = true;
    // screenAngle(): right == pi/2 — clamp aim to the right half-plane.
    player.aimClampCenter = pi / 2;
    player.aimClampRange = pi / 2;
    player.position = playerPosition.clone();
    player.angle = 0; // nose right

    game.cameraLocked = true;
    game.setZoomDirect(rocksZoom);
    _frameCamera();

    unawaited(_run());
  }

  /// Places the camera so the player appears at [playerScreenFraction] of
  /// the view width, vertically centered.
  void _frameCamera() {
    final cam = game.camara;
    if (cam == null) return;
    final viewWidth = MyGame.logicalWidth / cam.viewfinder.zoom;
    cam.viewfinder.position = Vector2(
      playerPosition.x - (playerScreenFraction - 0.5) * viewWidth,
      playerPosition.y,
    );
  }

  void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  void cancel() {
    super.cancel();
    _complete(_rocksCompleter);
    _complete(_circleCompleter);
    _complete(_circlesCompleter);
  }

  void _spawnRocks() {
    _rocksDestroyed = 0;
    _rocksCompleter = Completer<void>();
    for (final pos in [
      Vector2(450, 320),
      Vector2(485, 380),
      Vector2(515, 435),
    ]) {
      game.universo.add(
        RockTarget(
          position: pos,
          onDestroyed: () {
            _rocksDestroyed++;
            if (_rocksDestroyed >= 3) _complete(_rocksCompleter);
          },
        ),
      );
    }
  }

  void _spawnCircle(Vector2 pos) {
    _circleCompleter = Completer<void>();
    game.universo.add(
      CircleTarget(
        position: pos,
        onDestroyed: () => _complete(_circleCompleter),
      ),
    );
  }

  void _spawnCircles() {
    _circlesDestroyed = 0;
    _circlesCompleter = Completer<void>();
    for (final pos in [
      Vector2(560, 300),
      Vector2(650, 380),
      Vector2(560, 460),
    ]) {
      game.universo.add(
        CircleTarget(
          position: pos,
          onDestroyed: () {
            _circlesDestroyed++;
            if (_circlesDestroyed >= 3) _complete(_circlesCompleter);
          },
        ),
      );
    }
  }

  Future<void> _run() async {
    // Phase 1: rocks.
    _spawnRocks();
    await _rocksCompleter?.future;
    if (cancelled) return;

    await waitSeconds(2);
    if (cancelled) return;
    await animateZoom(circleZoom, 3);
    if (cancelled) return;

    // Phase 2: single regenerating orb (charge-shot lesson).
    _spawnCircle(Vector2(560, 380));
    await _circleCompleter?.future;
    if (cancelled) return;

    await waitSeconds(2);
    if (cancelled) return;
    await animateZoom(circlesZoom, 3);
    if (cancelled) return;

    // Phase 3: three orbs.
    _spawnCircles();
    await _circlesCompleter?.future;
    if (cancelled) return;

    await waitSeconds(1);
    if (cancelled) return;

    // Title card, then the first real level loads behind the black screen.
    await game.presentLevelTitle('SECTOR 7', () {
      game.startLevel(SectorLevel.sector7());
    });
  }
}
