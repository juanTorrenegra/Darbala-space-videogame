import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:juanshooter/actors/crab_enemy.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/ranged_enemy.dart';
import 'package:juanshooter/components/scenery_sprite.dart';
import 'package:juanshooter/components/space_rock.dart';
import 'package:juanshooter/components/target_roam.dart';
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
    this.nextIndex,
  });

  @override
  final String title;

  /// Shown on the title card after this sector is cleared.
  final String nextTitle;

  /// Spawns the scenery and enemies of this sector.
  final Future<void> Function(MyGame game) spawnScene;

  /// Index into [_campaign] for the following sector, or null after the last.
  final int? nextIndex;

  /// Center of the playfield (the original spawn point of the prototype).
  static final Vector2 center = Vector2(380, 380);

  static const double introSeconds = 1.6;
  static const double outroRotateSeconds = 0.45;
  static const double outroSpeed = 260;

  static const int _baseEnemyCount = 20;
  static const int _enemiesPerSector = 15;
  static const int _thingyRockCount = 30;

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

  /// First combat sector. Menu / tutorial / account all enter here.
  factory SectorLevel.sector7() => SectorLevel.at(0);

  /// Combat sector [index] in play order (0 = first, 7 = last).
  factory SectorLevel.at(int index) {
    final clamped = index.clamp(0, _campaign.length - 1);
    final spec = _campaign[clamped];
    final hasNext = clamped + 1 < _campaign.length;
    return SectorLevel(
      title: spec.title,
      nextTitle: spec.nextTitle,
      spawnScene: spec.spawnScene,
      nextIndex: hasNext ? clamped + 1 : null,
    );
  }

  static final List<_SectorSpec> _campaign = [
    _SectorSpec(
      title: 'SECTOR 7',
      nextTitle: 'SECTOR 8',
      spawnScene: _spawnSector7Scene,
    ),
    _SectorSpec(
      title: 'SECTOR 8',
      nextTitle: 'SECTOR 7',
      spawnScene: _spawnBrownPlanetScene,
    ),
    _SectorSpec(
      title: 'SECTOR 7',
      nextTitle: 'SECTOR 6',
      spawnScene: _spawnNebulaRockScene,
    ),
    _SectorSpec(
      title: 'SECTOR 6',
      nextTitle: 'SECTOR 5',
      spawnScene: _spawnSunScene,
    ),
    _SectorSpec(
      title: 'SECTOR 5',
      nextTitle: 'SECTOR 4',
      spawnScene: _spawnIceScene,
    ),
    _SectorSpec(
      title: 'SECTOR 4',
      nextTitle: 'SECTOR 3',
      spawnScene: _spawnGasGiantScene,
    ),
    _SectorSpec(
      title: 'SECTOR 3',
      nextTitle: 'SECTOR 2',
      spawnScene: _spawnFourNebulaScene,
    ),
    _SectorSpec(
      title: 'SECTOR 2',
      nextTitle: 'SECTOR 1',
      spawnScene: _spawnRedGiantScene,
    ),
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    game.cameraLocked = true;
    game.controlsLocked = true;
    game.enemyAlertsEnabled = false;
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
    game.enemyAlertsEnabled = true;
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
    // The exit fakes a 260-speed velocity for the trail; without this the
    // starfield would tear past as if the ship had gone into overdrive.
    game.parallaxFollowsPlayer = false;
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

    final following = nextIndex;
    await game.presentLevelTitle(nextTitle, () {
      if (following != null) {
        game.startLevel(SectorLevel.at(following));
      } else {
        game.returnToMenuBehindBlack();
      }
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

  // ------------------------------------------------------- shared spawn

  static int _enemyCountFor(int campaignIndex) =>
      _baseEnemyCount + campaignIndex * _enemiesPerSector;

  static Future<void> _addScenery(
    MyGame game,
    String file,
    Vector2 position,
    double scale, {
    int priority = -1,
  }) async {
    final sprite = await Sprite.load(file);
    game.universo.add(
      ScenerySprite(
        sprite: sprite,
        position: position,
        size: sprite.originalSize * scale,
        priority: priority,
      ),
    );
  }

  static List<int> _clusterSizes(int count) {
    final sizes = <int>[];
    var remaining = count;
    var pattern = 0;
    while (remaining > 0) {
      if (remaining >= 3 && remaining <= 5) {
        sizes.add(remaining);
        break;
      }
      if (remaining < 3) {
        var i = sizes.length - 1;
        while (remaining > 0 && i >= 0) {
          if (sizes[i] < 5) {
            sizes[i]++;
            remaining--;
          } else {
            i--;
          }
        }
        if (remaining > 0) {
          sizes[sizes.length - 1] = 3;
          sizes.add(2 + remaining);
          remaining = 0;
        }
        break;
      }
      final next = 3 + (pattern % 3);
      sizes.add(next);
      remaining -= next;
      pattern++;
    }
    return sizes;
  }

  static List<Vector2> _clusterOrigins(int n) {
    final out = <Vector2>[];
    var ring = 0;
    while (out.length < n) {
      final radius = 300.0 + ring * 210.0;
      final slots = min(n - out.length, 5 + ring * 3);
      for (var i = 0; i < slots; i++) {
        final a = (2 * pi * i) / slots + ring * 0.37;
        out.add(
          Vector2(center.x + cos(a) * radius, center.y + sin(a) * radius),
        );
      }
      ring++;
    }
    return out;
  }

  static Future<void> _spawnEnemyClusters(MyGame game, int count) async {
    final crabSprite = await Sprite.load('zombieTargetM500.png');
    final rangedSprite = await Sprite.load('z01px130.png');
    final satSprite = await Sprite.load('zombieSatelite240px.png');
    final sizes = _clusterSizes(count);
    final origins = _clusterOrigins(sizes.length);
    final rng = Random(count * 17 + sizes.length);

    for (var c = 0; c < sizes.length; c++) {
      final origin = origins[c];
      final n = sizes[c];
      for (var i = 0; i < n; i++) {
        final a = (2 * pi * i) / n + rng.nextDouble() * 0.4;
        final dist = 26.0 + rng.nextDouble() * 22;
        final pos = Vector2(
          origin.x + cos(a) * dist,
          origin.y + sin(a) * dist,
        );
        if (i == 0 && n >= 5 && rng.nextBool()) {
          game.universo.add(
            RangedEnemy(
              sprite: satSprite,
              position: pos,
              size: Vector2(60, 60),
              maxHitPoints: 200,
              rotationSpeed: 3.0,
              bulletSpeed: 50,
              shootingThreshold: 30,
              damage: 10,
            ),
          );
        } else if (i.isEven) {
          final side = 20.0 + rng.nextDouble() * 10;
          game.universo.add(
            CrabEnemy(
              sprite: crabSprite,
              position: pos,
              size: Vector2(side, side),
              maxHitPoints: 50,
              rotationSpeed: 4.0,
              damage: 30,
              patrolRadius: 70 + rng.nextDouble() * 40,
            ),
          );
        } else {
          final side = 25.0 + rng.nextDouble() * 10;
          game.universo.add(
            RangedEnemy(
              sprite: rangedSprite,
              position: pos,
              size: Vector2(side, side),
              maxHitPoints: 40,
              rotationSpeed: 3.0,
              bulletSpeed: 50,
              shootingThreshold: 30,
              damage: 10,
            ),
          );
        }
      }
    }
  }

  static Future<void> _spawnThingyRocks(MyGame game) async {
    final sprite = await Sprite.load(SpaceRock.spriteFile);
    final rng = Random(42);
    final placed = <Vector2>[];

    Vector2 nextPoint() {
      for (var attempt = 0; attempt < 24; attempt++) {
        final r = 140.0 + rng.nextDouble() * 620;
        final a = rng.nextDouble() * 2 * pi;
        final p = Vector2(center.x + cos(a) * r, center.y + sin(a) * r);
        if (p.distanceTo(center) < 110) continue;
        var ok = true;
        for (final other in placed) {
          if (p.distanceTo(other) < 90) {
            ok = false;
            break;
          }
        }
        if (ok) return p;
      }
      final a = placed.length * 0.9;
      return Vector2(center.x + cos(a) * 400, center.y + sin(a) * 400);
    }

    for (var i = 0; i < _thingyRockCount; i++) {
      final p = nextPoint();
      placed.add(p);
      final sizeScale = 0.5 + rng.nextDouble() * 0.5;
      final roamRadius = 40 + rng.nextDouble() * 90;
      final roam = GlideRoam(
        center: p,
        radius: roamRadius,
        angularSpeed: (0.08 + rng.nextDouble() * 0.18) * 0.5,
        phase: rng.nextDouble() * 2 * pi,
      );
      game.universo.add(
        SpaceRock(
          sprite: sprite,
          position: roam.startPoint,
          sizeScale: sizeScale,
          angle: rng.nextDouble() * 2 * pi,
          idleSpin: (rng.nextDouble() - 0.5) * 0.11,
          roam: roam,
        ),
      );
    }
  }

  // ------------------------------------------------------- sector scenes

  /// The original prototype world: 4 scenery pieces + 20 enemies.
  static Future<void> _spawnSector7Scene(MyGame game) async {
    final universo = game.universo;

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
        position: Vector2(-100, 380),
        size: Vector2(550, 500),
        priority: -1,
      ),
    );

    universo.add(
      RangedEnemy(
        sprite: await Sprite.load('zombieSatelite240px.png'),
        position: Vector2(685, 380),
        size: Vector2(60, 60),
        maxHitPoints: 200,
        rotationSpeed: 3.0,
        bulletSpeed: 50,
        shootingThreshold: 30,
        damage: 10,
      ),
    );
    universo.add(
      CrabEnemy(
        sprite: await Sprite.load('z01px130.png'),
        position: Vector2(620, 350),
        size: Vector2(30, 30),
        maxHitPoints: 50,
        rotationSpeed: 4.0,
        damage: 30,
      ),
    );
    final rangedSprite = await Sprite.load('z01px130.png');
    universo.add(
      RangedEnemy(
        sprite: rangedSprite,
        position: Vector2(620, 330),
        size: Vector2(25, 25),
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
        size: Vector2(35, 35),
        maxHitPoints: 40,
        rotationSpeed: 3.0,
        bulletSpeed: 50,
        shootingThreshold: 30,
        damage: 10,
      ),
    );
    await game.spawnEdgePatrolCrabs(origin: center);
  }

  static Future<void> _spawnNebulaGrid(
    MyGame game,
    List<String> files, {
    double scale = 1,
  }) async {
    var cellW = 0.0;
    var cellH = 0.0;
    final sprites = <Sprite>[];
    for (final file in files) {
      final sprite = await Sprite.load(file);
      sprites.add(sprite);
      cellW = max(cellW, sprite.originalSize.x * scale);
      cellH = max(cellH, sprite.originalSize.y * scale);
    }
    final dx = cellW / 2;
    final dy = cellH / 2;
    final origins = [
      Vector2(-dx, -dy),
      Vector2(dx, -dy),
      Vector2(-dx, dy),
      Vector2(dx, dy),
    ];
    for (var i = 0; i < sprites.length; i++) {
      game.universo.add(
        ScenerySprite(
          sprite: sprites[i],
          position: center + origins[i],
          size: sprites[i].originalSize * scale,
          priority: -3,
        ),
      );
    }
  }

  static Future<void> _spawnBrownPlanetScene(MyGame game) async {
    await _addScenery(
      game,
      'Nebula3.png',
      Vector2(420, 300),
      6,
      priority: -3,
    );
    await _addScenery(
      game,
      'bbrownplanet.png',
      Vector2(center.x - 240, center.y),
      1,
    );
    await _addScenery(
      game,
      'basteroids.png',
      Vector2(center.x + 260, center.y),
      1,
      priority: -2,
    );
    await _spawnEnemyClusters(game, _enemyCountFor(1));
  }

  static Future<void> _spawnNebulaRockScene(MyGame game) async {
    await _spawnNebulaGrid(game, [
      'Nebula2.png',
      'Nebula2.png',
      'Nebula2.png',
      'Nebula2.png',
    ]);
    await _spawnThingyRocks(game);
    await _spawnEnemyClusters(game, _enemyCountFor(2));
  }

  static Future<void> _spawnSunScene(MyGame game) async {
    await _addScenery(game, 'bsun.png', center.clone(), 1);
    await _spawnEnemyClusters(game, _enemyCountFor(3));
  }

  static Future<void> _spawnIceScene(MyGame game) async {
    await _addScenery(game, 'Nebula1.png', center.clone(), 2, priority: -3);
    await _addScenery(
      game,
      'bicegigant.png',
      Vector2(center.x, center.y - 260),
      1,
    );
    await _spawnEnemyClusters(game, _enemyCountFor(4));
  }

  static Future<void> _spawnGasGiantScene(MyGame game) async {
    await _addScenery(game, 'Nebula3.png', center.clone(), 2, priority: -3);
    await _addScenery(
      game,
      'bgasgigant.png',
      Vector2(center.x, center.y + 260),
      1,
    );
    await _spawnEnemyClusters(game, _enemyCountFor(5));
  }

  static Future<void> _spawnFourNebulaScene(MyGame game) async {
    await _spawnNebulaGrid(game, [
      'Nebula1.png',
      'Nebula2.png',
      'Nebula3.png',
      'Nebula2.png',
    ]);
    await _spawnEnemyClusters(game, _enemyCountFor(6));
  }

  static Future<void> _spawnRedGiantScene(MyGame game) async {
    await _addScenery(game, 'bredgigant.png', center.clone(), 1.5);
    await _spawnThingyRocks(game);
    await _spawnEnemyClusters(game, _enemyCountFor(7));
  }
}

class _SectorSpec {
  const _SectorSpec({
    required this.title,
    required this.nextTitle,
    required this.spawnScene,
  });

  final String title;
  final String nextTitle;
  final Future<void> Function(MyGame game) spawnScene;
}
