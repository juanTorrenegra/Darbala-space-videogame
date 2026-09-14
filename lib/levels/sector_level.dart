import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:juanshooter/actors/crab_enemy.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/ranged_enemy.dart';
import 'package:juanshooter/components/scenery_sprite.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/levels/game_level.dart';

/// A combat sector: destroy every enemy to complete it.
///
/// Intro: the ship slides in from outside the left camera edge to the center
/// (camera fixed), then "DESTRUYE A TODOS LOS ENEMIGOS" shows for 2 s and
/// control is handed over.
///
/// Outro: once no [Enemigo] remains, the ship turns to face right and exits
/// through the right camera edge while the camera stays put; 2 s later the
/// next sector's title card plays.
class SectorLevel extends GameLevel {
  SectorLevel({
    required this.title,
    required this.nextTitle,
    required this.spawnScene,
  });

  @override
  final String title;

  /// Shown on the title card after this sector is cleared.
  final String nextTitle;

  /// Spawns the scenery and enemies of this sector.
  final Future<void> Function(MyGame game) spawnScene;

  /// Center of the playfield (the original spawn point of the prototype).
  static final Vector2 center = Vector2(380, 380);

  static const double introSeconds = 1.6;
  static const double outroRotateSeconds = 0.45;
  static const double outroSpeed = 260;

  double _introElapsed = 0;
  final Vector2 _introFrom = Vector2.zero();
  bool _ready = false;
  bool _introDone = false;
  bool _bannerStarted = false;

  bool _outroStarted = false;
  bool _outroThrusting = false;
  double _outroRotateElapsed = 0;
  double _outroFromAngle = 0;
  Completer<void>? _exitCompleter;

  /// The current production world, as the first real level.
  factory SectorLevel.sector7() {
    return SectorLevel(
      title: 'SECTOR 7',
      nextTitle: 'SECTOR 8',
      spawnScene: _spawnSector7Scene,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    game.cameraLocked = true;
    game.controlsLocked = true;
    game.setZoomDirect(MyGame.defaultZoom);
    game.camara?.viewfinder.position = center.clone();

    await spawnScene(game);
    if (cancelled) return;

    // Ship starts outside the left camera edge and slides to the center.
    final half = game.visibleWorldHalf();
    final player = game.player;
    _introFrom.setValues(center.x - (half?.x ?? 560) - 60, center.y);
    player.position = _introFrom.clone();
    player.angle = 0; // nose right
    _ready = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (cancelled || !_ready) return;

    if (!_introDone) {
      _updateIntro(dt);
      return;
    }

    if (!_outroStarted) {
      if (_bannerStarted && _enemiesCleared()) {
        _startOutro();
      }
      return;
    }

    _updateOutro(dt);
  }

  // ---------------------------------------------------------------- intro

  void _updateIntro(double dt) {
    _introElapsed += dt;
    final t = (_introElapsed / introSeconds).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    game.player.position.setValues(
      _introFrom.x + (center.x - _introFrom.x) * eased,
      center.y,
    );
    // Fake velocity so the thruster trail emits while sliding in.
    game.player.velocity.setValues(150 * (1 - eased), 0);
    if (t >= 1) {
      _introDone = true;
      unawaited(_showBannerThenUnlock());
    }
  }

  Future<void> _showBannerThenUnlock() async {
    _bannerStarted = true;
    game.overlays.add('LevelBanner');
    await waitSeconds(2.6); // 0.3 s fade-in, 2 s hold, 0.3 s fade-out
    if (cancelled) return;
    game.overlays.remove('LevelBanner');
    game.controlsLocked = false;
    game.cameraLocked = false;
    game.snapViewfinderToPlayer();
  }

  // ---------------------------------------------------------------- outro

  bool _enemiesCleared() {
    return game.universo.children.whereType<Enemigo>().isEmpty;
  }

  void _startOutro() {
    _outroStarted = true;
    _outroThrusting = false;
    _outroRotateElapsed = 0;
    _outroFromAngle = game.player.angle;
    _exitCompleter = Completer<void>();

    game.controlsLocked = true;
    game.cameraLocked = true; // freeze the current camera view
    if (game.hud.isLoaded) {
      game.hud.cancelCharge();
    }

    unawaited(_runOutro());
  }

  void _updateOutro(double dt) {
    final player = game.player;

    if (!_outroThrusting) {
      // Face right first (angle 0), the shortest way around.
      _outroRotateElapsed += dt;
      final t = (_outroRotateElapsed / outroRotateSeconds).clamp(0.0, 1.0);
      player.angle = _lerpAngle(
        _outroFromAngle,
        0,
        Curves.easeInOut.transform(t),
      );
      if (t >= 1) {
        _outroThrusting = true;
      }
      return;
    }

    player.position.x += outroSpeed * dt;
    // Fake velocity so the thruster trail emits while exiting.
    player.velocity.setValues(outroSpeed, 0);

    final cam = game.camara;
    if (cam != null) {
      final halfX = MyGame.logicalWidth / cam.viewfinder.zoom / 2;
      if (player.position.x > cam.viewfinder.position.x + halfX + 60) {
        final completer = _exitCompleter;
        _exitCompleter = null;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
    }
  }

  Future<void> _runOutro() async {
    await _exitCompleter?.future;
    if (cancelled) return;

    await waitSeconds(2);
    if (cancelled) return;

    // No further sectors exist yet: the card plays and the game returns to
    // the main menu behind the black screen.
    await game.presentLevelTitle(nextTitle, () {
      game.returnToMenuBehindBlack();
    });
  }

  static double _lerpAngle(double from, double to, double t) {
    var d = (to - from) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    return from + d * t;
  }

  @override
  void cancel() {
    super.cancel();
    final completer = _exitCompleter;
    _exitCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  void onRemove() {
    // Never leave the banner stuck on screen if the level dies mid-intro.
    if (game.overlays.isActive('LevelBanner')) {
      game.overlays.remove('LevelBanner');
    }
    super.onRemove();
  }

  // ------------------------------------------------------- sector 7 scene

  /// The original prototype world: 4 scenery pieces + 20 enemies.
  static Future<void> _spawnSector7Scene(MyGame game) async {
    final universo = game.universo;

    // --- Scenery (below the player): nebulae behind, planets in front.
    universo.add(
      ScenerySprite(
        sprite: await Sprite.load('Nebula1.png'),
        position: Vector2(1000, 150),
        size: Vector2(1500, 1128),
        priority: -3,
      ),
    );
    universo.add(
      ScenerySprite(
        sprite: await Sprite.load('Nebula2.png'),
        position: Vector2(200, 950),
        size: Vector2(1600, 1438),
        priority: -3,
      ),
    );
    universo.add(
      ScenerySprite(
        sprite: await Sprite.load('bgasgigant.png'),
        position: Vector2(-800, 380),
        size: Vector2(1800, 1700),
        priority: -1,
      ),
    );
    universo.add(
      ScenerySprite(
        sprite: await Sprite.load('bplanet.png'),
        position: Vector2(1300, 500),
        size: Vector2(1800, 1700),
        priority: -1,
      ),
    );

    // --- Enemies (the original 20).
    universo.add(
      RangedEnemy(
        sprite: await Sprite.load('verdePequeno.png'),
        position: Vector2(660, 380),
        size: Vector2(16, 16),
        maxHitPoints: 200,
        rotationSpeed: 3.0,
        bulletSpeed: 50,
        shootingThreshold: 30,
        damage: 10,
      ),
    );
    universo.add(
      CrabEnemy(
        sprite: await Sprite.load('10.png'),
        position: Vector2(620, 350),
        size: Vector2(20, 20),
        maxHitPoints: 50,
        rotationSpeed: 4.0,
        damage: 30,
      ),
    );
    final rangedSprite = await Sprite.load('verdePequeno.png');
    universo.add(
      RangedEnemy(
        sprite: rangedSprite,
        position: Vector2(620, 330),
        size: Vector2(18, 18),
        maxHitPoints: 40,
        rotationSpeed: 3.0,
        bulletSpeed: 50,
        shootingThreshold: 30,
        damage: 10,
      ),
    );
    universo.add(
      RangedEnemy(
        sprite: rangedSprite,
        position: Vector2(630, 385),
        size: Vector2(18, 18),
        maxHitPoints: 40,
        rotationSpeed: 3.0,
        bulletSpeed: 50,
        shootingThreshold: 30,
        damage: 10,
      ),
    );
    await game.spawnEdgePatrolCrabs(origin: center);
  }
}
