import 'dart:async';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/components.dart';
import 'package:juanshooter/components/circle_target.dart';
import 'package:juanshooter/components/rock_target.dart';
import 'package:juanshooter/components/scenery_sprite.dart';
import 'package:juanshooter/components/target_roam.dart';
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
/// 2. Pause — zoom animates 3.5 → 3.0.
/// 3. One regenerating orb (49 HP, +10 HP / 0.3 s, min 1 HP) — only a fully
///    charged shot (50 dmg) destroys it.
/// 4. Pause — zoom animates 3.0 → 2.5.
/// 5. Three orbs — same charge-to-destroy rule.
/// 6. Pause — zoom animates 2.5 → 1.8, then the movement lesson: the ship is
///    pushed off the arm, free flight is unlocked inside the 2×3 tile world,
///    and 5 roaming targets must be destroyed (edge triangles point at the
///    ones off-screen).
/// 7. Pause — "SECTOR 7" title card (blur, glitches, black), then the
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
  static const double movementZoom = 1.8;

  /// Length of each scripted zoom animation.
  static const double zoomSeconds = 1.5;

  /// Beat between phases, and the shorter one before/after the movement phase.
  static const double phasePause = 1.0;
  static const double shortPause = 0.5;

  /// Where the static ship sits for the whole tutorial.
  static final Vector2 playerPosition = Vector2(350, 365);

  /// Ship X on screen: 1/4 of the view width from the left.
  static const double playerScreenFraction = 0.25;

  /// Background grid: 2 columns × 3 rows. The ship starts on the mecha arm in
  /// the left column, middle row.
  static const int gridCols = 2;
  static const int gridRows = 3;
  static const double tileScale = 0.6;

  /// Sideways kick that launches the ship off the arm when movement unlocks.
  /// The level glides the ship itself: [Player] caps its own velocity at
  /// `currentSpeed` (50), which would swallow most of the shove.
  static const double launchSpeed = 150;

  /// Speed shed per second during the launch — 150 over 105 gives a ~1.4 s
  /// glide covering roughly 107 world units.
  static const double launchDrag = 105;

  /// Roaming targets to clear before the tutorial ends: 3 orbs + 2 rocks.
  static const int roamingTargetCount = 5;

  int _rocksDestroyed = 0;
  Completer<void>? _rocksCompleter;
  Completer<void>? _circleCompleter;
  int _circlesDestroyed = 0;
  Completer<void>? _circlesCompleter;
  int _roamersDestroyed = 0;
  Completer<void>? _roamersCompleter;

  /// Once true the level stops framing the camera and the game takes over.
  bool _freeFlight = false;

  /// Remaining speed of the launch glide; 0 once the player has control.
  double _launchSpeed = 0;

  Vector2 _tileSize = Vector2.zero();
  Vector2 _homeTileCenter = Vector2.zero();

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
    // Fence the camera from the start: the later zoom-outs are wide enough to
    // see past the tiles otherwise.
    game.cameraWorldBounds = _worldBounds;
    await _spawnMechaArm();
    _frameCamera();

    unawaited(_run());
  }

  /// Static mechanical arm reaching in from off-screen left. It starts just
  /// outside [_worldBounds], which the camera never looks past, so its base
  /// stays clipped at every zoom.
  Future<void> _spawnMechaArm() async {
    final sprite = await Sprite.load('mechaArm2.png');
    const armWidth = 170.0;
    final armHeight = armWidth * sprite.originalSize.y / sprite.originalSize.x;
    final startX = _worldBounds.left - 8;
    game.universo.add(
      ScenerySprite(
        sprite: sprite,
        position: Vector2(startX + armWidth / 2, playerPosition.y),
        size: Vector2(armWidth, armHeight),
        priority: -5,
      ),
    );
  }

  /// Lays out the 2×3 tile world. The home tile (left column, middle row) is
  /// centered on the shooting-phase camera so zooms 3.5→2.5 stay filled.
  Future<void> _spawnBackground() async {
    final sprite = await Sprite.load('tutorialBG4.png');
    _tileSize = sprite.originalSize * tileScale;
    final viewW = MyGame.logicalWidth / circlesZoom;
    _homeTileCenter = Vector2(
      playerPosition.x - (playerScreenFraction - 0.5) * viewW,
      playerPosition.y,
    );
    for (var col = 0; col < gridCols; col++) {
      for (var row = 0; row < gridRows; row++) {
        game.universo.add(
          ScenerySprite(
            sprite: sprite,
            position: _tileCenter(col, row),
            size: _tileSize.clone(),
            priority: -10,
          ),
        );
      }
    }
  }

  /// Center of the tile at [col], [row]; the home tile is (0, 1).
  Vector2 _tileCenter(int col, int row) => Vector2(
    _homeTileCenter.x + col * _tileSize.x,
    _homeTileCenter.y + (row - 1) * _tileSize.y,
  );

  /// World rect covering all 6 tiles — the camera never looks past it.
  Rect get _worldBounds => Rect.fromLTWH(
    _homeTileCenter.x - _tileSize.x / 2,
    _homeTileCenter.y - _tileSize.y * 1.5,
    _tileSize.x * gridCols,
    _tileSize.y * gridRows,
  );

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
    // At the widest zoom the framing above would reach past the tiles.
    game.clampViewfinderToWorldBounds();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_freeFlight) {
      // Keep the same screen composition while zoom animates.
      _frameCamera();
      return;
    }
    _updateLaunch(dt);
  }

  /// Slides the ship off the arm and feeds [Player.velocity] so the thruster
  /// trail fires. Control is handed over once the glide runs out.
  void _updateLaunch(double dt) {
    if (_launchSpeed <= 0) return;
    final player = game.player;
    player.position.x += _launchSpeed * dt;
    player.velocity.setValues(_launchSpeed, 0);
    _launchSpeed -= launchDrag * dt;
    if (_launchSpeed <= 0) {
      _launchSpeed = 0;
      player.velocity.setZero();
      player.staticAimOnly = false;
    }
  }

  void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  void cancel() {
    super.cancel();
    if (game.hud.isLoaded) {
      game.hud.shootHint.stop();
    }
    game.cameraWorldBounds = null;
    _complete(_rocksCompleter);
    _complete(_circleCompleter);
    _complete(_circlesCompleter);
    _complete(_roamersCompleter);
  }

  void _spawnRocks() {
    _rocksDestroyed = 0;
    _rocksCompleter = Completer<void>();
    final positions = [
      Vector2(450, 320),
      Vector2(485, 380),
      Vector2(515, 435),
    ];
    for (var i = 0; i < positions.length; i++) {
      game.universo.add(
        RockTarget(
          position: positions[i],
          spriteFile: RockTarget.spriteFiles[i],
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

  /// Opens up aiming, hands the camera to the game's follow logic (still
  /// fenced by [MyGame.cameraWorldBounds]), and kicks the ship off the arm.
  void _startFreeFlight() {
    final player = game.player;
    // Aim opens up immediately; thrust waits until the launch glide ends so
    // the level and the player are not moving the ship at the same time.
    player.aimClampCenter = null;

    _freeFlight = true;
    game.cameraLocked = false;
    game.snapViewfinderToPlayer();
    _launchSpeed = launchSpeed;
  }

  /// 3 patrolling orbs down the right column, 2 rocks gliding around the
  /// tiles above and below the start.
  void _spawnRoamingTargets() {
    _roamersDestroyed = 0;
    _roamersCompleter = Completer<void>();
    void onKill() {
      _roamersDestroyed++;
      if (_roamersDestroyed >= roamingTargetCount) {
        _complete(_roamersCompleter);
      }
    }

    final areaRadius = min(_tileSize.x, _tileSize.y) * 0.3;
    for (var row = 0; row < gridRows; row++) {
      final center = _tileCenter(1, row);
      game.universo.add(
        CircleTarget(
          position: center.clone(),
          roam: PatrolRoam(origin: center, radius: areaRadius),
          onDestroyed: onKill,
        ),
      );
    }
    for (final row in [0, 2]) {
      final roam = GlideRoam(
        center: _tileCenter(0, row),
        radius: areaRadius * 0.8,
        phase: row == 0 ? pi : 0,
      );
      game.universo.add(
        RockTarget(
          position: roam.startPoint,
          roam: roam,
          onDestroyed: onKill,
        ),
      );
    }
  }

  Future<void> _run() async {
    // Phase 1: rocks.
    _spawnRocks();
    game.hud.shootHint.startTapLaser();
    await _rocksCompleter?.future;
    if (cancelled) return;
    game.hud.shootHint.stop();

    await waitSeconds(phasePause);
    if (cancelled) return;
    await animateZoom(circleZoom, zoomSeconds);
    if (cancelled) return;

    // Phase 2: single regenerating orb (charge-shot lesson).
    _spawnCircle(Vector2(560, 380));
    game.hud.shootHint.startChargeLaser();
    await _circleCompleter?.future;
    if (cancelled) return;
    game.hud.shootHint.stop();

    await waitSeconds(phasePause);
    if (cancelled) return;
    await animateZoom(circlesZoom, zoomSeconds);
    if (cancelled) return;

    // Phase 3: three orbs.
    _spawnCircles();
    game.hud.shootHint.startChargeLaser();
    await _circlesCompleter?.future;
    if (cancelled) return;
    game.hud.shootHint.stop();

    // Phase 4: movement — pull the camera back, then unlock free flight and
    // clear the roaming targets.
    await waitSeconds(shortPause);
    if (cancelled) return;
    await animateZoom(movementZoom, zoomSeconds);
    if (cancelled) return;
    _startFreeFlight();
    _spawnRoamingTargets();
    await _roamersCompleter?.future;
    if (cancelled) return;

    await waitSeconds(shortPause);
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
