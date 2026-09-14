import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:juanshooter/components/circle_target.dart';
import 'package:juanshooter/components/rock_target.dart';
import 'package:juanshooter/components/scenery_sprite.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/levels/game_level.dart';
import 'package:juanshooter/levels/sector_level.dart';

/// Level 0 — shooting tutorial.
///
/// The ship sits static at 1/4 of the view width, vertically centered;
/// the movement stick only aims, clamped to a 180° cone facing right.
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
  TutorialLevel({this.promptAccountAfter = false});

  /// When true (first-time player), the SECTOR 7 black screen stays up and
  /// the create-account overlay is shown on top of it.
  final bool promptAccountAfter;

  /// Camera zoom for each phase of the tutorial.
  static const double rocksZoom = 3.5;
  static const double circleZoom = 3.0;
  static const double circlesZoom = 2.5;

  /// Where the static ship sits for the whole tutorial.
  static final Vector2 playerPosition = Vector2(350, 365);

  /// Ship X on screen: 1/4 of the view width from the left.
  static const double playerScreenFraction = 0.25;

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
    await _spawnBackground();

    unawaited(_run());
  }

  /// Covers the widest tutorial camera (circlesZoom) so zooms 4.5→2.5 stay filled.
  Future<void> _spawnBackground() async {
    final sprite = await Sprite.load('tutorialBG4.png');
    final viewW = MyGame.logicalWidth / circlesZoom;
    final viewH = MyGame.logicalHeight / circlesZoom;
    final src = sprite.originalSize;
    final cover = max(viewW / src.x, viewH / src.y);
    final viewfinder = Vector2(
      playerPosition.x - (playerScreenFraction - 0.5) * viewW,
      playerPosition.y,
    );
    game.universo.add(
      ScenerySprite(
        sprite: sprite,
        position: viewfinder,
        size: src * 0.6,
        priority: -10,
      ),
    );
  }

  /// Viewfinder (anchor center) stays at the screen center. The ship is
  /// kept at [playerScreenFraction] of the width and halfway down the height.
  void _frameCamera() {
    final cam = game.camara;
    if (cam == null) return;
    cam.viewfinder.anchor = Anchor.center;
    final viewSize = cam.viewport.virtualSize;
    final zoom = cam.viewfinder.zoom.clamp(0.01, 100.0);
    final viewWidth = viewSize.x / zoom;
    cam.viewfinder.position = Vector2(
      playerPosition.x - (playerScreenFraction - 0.5) * viewWidth,
      playerPosition.y,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Keep the same screen composition while zoom animates.
    _frameCamera();
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

    // Title card, then either account creation (new player) or Sector 7.
    await game.presentLevelTitle('SECTOR 7', () {
      if (promptAccountAfter) {
        game.promptAccountOnBlackScreen();
      } else {
        game.startLevel(SectorLevel.sector7());
      }
    }, dismissAfterLoad: !promptAccountAfter);
  }
}
