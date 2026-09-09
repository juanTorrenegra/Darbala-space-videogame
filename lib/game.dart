import 'dart:async';
import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/player.dart';
import 'package:juanshooter/actors/ranged_enemy.dart';
import 'package:juanshooter/actors/spike_enemy.dart';
import 'package:juanshooter/actors/crab_enemy.dart';
import 'package:juanshooter/hud/game_hud.dart';
import 'package:juanshooter/hud/offscreen_enemy_markers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:juanshooter/overlays/game_over.dart';
import 'package:juanshooter/weapons/bullet.dart';
import 'package:juanshooter/weapons/enemy_bullet.dart';
import 'package:juanshooter/effects/explosion_particles.dart';

// Logical game frame = 1280×720 (16:9). See MyGame.logicalWidth / logicalHeight.
// juego: nave que elimina asteroides para encontrar armas para derrotar monstruos del espacio, escenario: dentro de un imperio y uno es un minero: mision: minar y mejorar la nave para poder acceder a MediumWorld y HardWorld, competir contra otros mineros compitiendo y compartiendo loot.

//prototipo

enum AppStickMode { single, dual }

class MyGame extends FlameGame
    with
        HasGameReference<MyGame>,
        HasCollisionDetection,
        flame_events.MouseMovementDetector,
        flame_events.PanDetector {
  MyGame({this.onRunEnded});

  /// Called once when a run ends so the app layer can POST the scor
  final void Function(int score)? onRunEnded;

  /// Fixed design resolution (16:9). The Flutter shell letterboxes this frame;
  /// resizing the browser scales it instead of showing more of the world
  static const double logicalWidth = 1560;
  static const double logicalHeight = 720;

  /// Tope de vida al empezar una run nueva (menú / partida desde cero).
  static const int basePlayerMaxHitPoints = 100;

  /// Máximo de vida de la run: persiste al morir y al `recreatePlayer`; los power-ups lo aumentan.
  int playerMaxHitPoints = basePlayerMaxHitPoints;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int shipsDestroyed = 0;
  late Player player;
  late RangedEnemy enemigo2;

  late final GameHud hud;
  late final World universo;
  CameraComponent? camara;
  Vector2 currentPlayerPos = Vector2.zero();
  late AudioPool pool;
  final Map<String, AudioPlayer> _sfxPlayers = {};
  double timeScale = 1.0; //game speed!
  double cameraZoom = 2;
  static const double knockbackCameraHoldSeconds = 2.0;

  /// How far the viewfinder leads the ship (world units). Screen center sits
  /// this far toward facing/thrust, so the ship sits the same distance opposite.
  /// Tweak this if 50 feels too tight or too wide.
  static const double cameraLookAheadRadius = 40;

  /// World-unit padding so the ship cannot reach the viewport edge.
  static const double cameraViewportMargin = 60;

  // --- Camera chase speeds (world units / sec). Tweak these. ---
  // Player cruise is ~50. Thrust chase must be *faster* so look-ahead can form.
  /// Holding a move direction (WASD / movement stick). Faster than the ship.
  static const double cameraThrustSpeed = 80;

  /// Quick swipe / not holding: slowly reframe toward the new facing.
  static const double cameraFacingSpeed = 20;

  /// Seconds to ease from 0 up to the current chase speed (spacey, not snappy).
  static const double cameraEaseInSeconds = 0.85;

  /// Move input shorter than this uses facing speed (a swipe, not a hold).
  static const double cameraThrustHoldDelay = 0.14;

  /// World units per second for knockback slides (player and enemies).
  double knockbackSpeed = 80;
  double _knockbackCameraHoldRemaining = 0;
  final Vector2 _cameraIntentDir = Vector2.zero();
  bool _hasCameraIntent = false;
  double _cameraChaseSpeed = 0;
  double _moveHoldTimer = 0;

  late ParallaxComponent spaceParallax;
  AppStickMode stickMode = AppStickMode.single;

  /// Web-only: phone-browser touch HUD (joystick + shoot). Off by default.
  bool cellularMode = false;

  /// Native app always uses sticks; web only when [cellularMode] is on.
  bool get useTouchControls => !kIsWeb || cellularMode;

  double spikeCurveStrength = 0.35;
  double spikeChargeSpeed = 70;
  double spikeBullRushSpeed = 230;
  double spikeChargeDuration = 2.0;
  double spikeRushDistanceMultiplier = 2.0;
  double spikeMinRushDistance = 220.0;

  // Método para cambiar la escala de tiempo
  void setStickMode(AppStickMode mode) {
    if (kIsWeb) return;
    stickMode = mode;
    _applyHudStickMode();
  }

  void setCellularMode(bool enabled) {
    if (!kIsWeb) return;
    cellularMode = enabled;
    _applyHudStickMode();
  }

  void _applyHudStickMode() {
    final viewport = camara?.viewport;
    if (viewport == null) return;
    for (final child in viewport.children.whereType<GameHud>()) {
      if (child.isLoaded) child.applyStickMode();
    }
  }

  void setTimeScale(double scale) {
    timeScale = scale.clamp(0.1, 5.0); // Limitar entre 0.1x y 5.0x
    print('Time scale set to: ${timeScale}x');
  }

  void setCameraZoom(double zoom) {
    cameraZoom = zoom.clamp(0.5, 3.0); // Limit zoom range
    if (camara != null) {
      camara!.viewfinder.zoom = cameraZoom;
      print('Zoom set to: ${cameraZoom}x');
    }
  }

  /// Knockback hits: freeze look-ahead so the viewfinder does not jump.
  /// Enemies without knockback should not call this.
  void detachViewfinderForKnockback() {
    camara?.stop();
    _knockbackCameraHoldRemaining = knockbackCameraHoldSeconds;
  }

  void applyPlayerKnockback(Vector2 delta, {double? speed}) {
    if (!player.isMounted || delta.length2 <= 0) return;
    player.startKnockback(delta, speed: speed ?? knockbackSpeed);
    detachViewfinderForKnockback();
  }

  void snapViewfinderToPlayer() {
    _knockbackCameraHoldRemaining = 0;
    _hasCameraIntent = false;
    _cameraChaseSpeed = 0;
    _moveHoldTimer = 0;
    _cameraIntentDir.setZero();
    camara?.stop();
    if (camara != null && player.isMounted) {
      _setViewfinderPosition(player.position);
    }
  }

  /// Viewfinder.position is a copy; mutating it in place does not move the camera.
  void _setViewfinderPosition(Vector2 worldPoint) {
    camara?.viewfinder.position = worldPoint.clone();
  }

  void _translateViewfinder(Vector2 delta) {
    final vf = camara?.viewfinder;
    if (vf == null) return;
    vf.position = vf.position + delta;
  }

  Vector2? _visibleWorldHalf() {
    final cam = camara;
    if (cam == null) return null;
    final viewSize = cam.viewport.virtualSize;
    final zoom = cam.viewfinder.zoom.clamp(0.01, 100.0);
    if (viewSize.x <= 0 || viewSize.y <= 0) return null;
    return Vector2(viewSize.x / zoom, viewSize.y / zoom) / 2;
  }

  /// True if [world] is inside the camera view, expanded by [margin] world units.
  bool isWorldPointVisible(Vector2 world, {double margin = 0}) {
    final cam = camara;
    final half = _visibleWorldHalf();
    if (cam == null || half == null) return true;
    final center = cam.viewfinder.position;
    return (world.x - center.x).abs() <= half.x + margin &&
        (world.y - center.y).abs() <= half.y + margin;
  }

  double _playerViewportRadius() {
    final half = _visibleWorldHalf();
    if (half == null) return cameraLookAheadRadius;
    final fit = min(half.x, half.y) - cameraViewportMargin;
    return min(cameraLookAheadRadius, max(8.0, fit));
  }

  void _clampPlayerToViewport() {
    final cam = camara;
    final half = _visibleWorldHalf();
    if (cam == null || half == null || !player.isMounted) return;
    final center = cam.viewfinder.position;
    player.containInWorldRect(
      minX: center.x - half.x + cameraViewportMargin,
      maxX: center.x + half.x - cameraViewportMargin,
      minY: center.y - half.y + cameraViewportMargin,
      maxY: center.y + half.y - cameraViewportMargin,
    );
  }

  void _clampViewfinderToPlayer(double radius) {
    final vf = camara?.viewfinder;
    if (vf == null || !player.isMounted) return;
    final offset = player.position - vf.position;
    final dist = offset.length;
    if (dist <= radius) return;
    _setViewfinderPosition(player.position - offset.normalized() * radius);
  }

  /// Look-ahead camera: start centered; lead the ship by [cameraLookAheadRadius]
  /// in the last move direction. Hold = fast chase, swipe = slow chase.
  /// Releasing thrust keeps the current frame (no recenter).
  void _updateSpaceCamera(double dt) {
    final cam = camara;
    if (cam == null || !player.isMounted) return;

    if (_knockbackCameraHoldRemaining > 0) {
      _knockbackCameraHoldRemaining -= dt;
      if (_knockbackCameraHoldRemaining < 0) {
        _knockbackCameraHoldRemaining = 0;
      }
      _clampViewfinderToPlayer(_playerViewportRadius());
      return;
    }

    final holding = hud.isLoaded && hud.effectiveMovementDelta.length2 > 0.0001;
    if (holding) {
      final inputDir = hud.effectiveMovementDelta.normalized();
      if (_hasCameraIntent && inputDir.dot(_cameraIntentDir) < 0.25) {
        _cameraChaseSpeed = 0;
      }
      _cameraIntentDir.setFrom(inputDir);
      _hasCameraIntent = true;
      _moveHoldTimer += dt;
    } else {
      _moveHoldTimer = 0;
    }

    if (!_hasCameraIntent) {
      _setViewfinderPosition(player.position);
      _cameraChaseSpeed = 0;
      return;
    }

    final thrusting = holding && _moveHoldTimer >= cameraThrustHoldDelay;
    final maxSpeed = thrusting ? cameraThrustSpeed : cameraFacingSpeed;
    final radius = _playerViewportRadius();
    final targetOffset = _cameraIntentDir * radius;
    final offset = cam.viewfinder.position - player.position;
    final delta = targetOffset - offset;
    final dist = delta.length;
    final snapDist = max(0.5, _cameraChaseSpeed * dt + 0.25);

    if (dist <= snapDist) {
      _setViewfinderPosition(player.position + targetOffset);
      if (!holding) {
        _cameraChaseSpeed = 0;
      }
      _clampViewfinderToPlayer(radius);
      return;
    }

    _easeCameraChaseSpeed(maxSpeed, dt);
    final step = min(_cameraChaseSpeed * dt, dist);
    _setViewfinderPosition(
      player.position + offset + delta.normalized() * step,
    );
    _clampViewfinderToPlayer(radius);
  }

  void _easeCameraChaseSpeed(double maxSpeed, double dt) {
    final easeRate =
        max(cameraThrustSpeed, cameraFacingSpeed) / cameraEaseInSeconds;
    if (_cameraChaseSpeed < maxSpeed) {
      final t = (_cameraChaseSpeed / maxSpeed).clamp(0.0, 1.0);
      final easeIn = 0.12 + 0.88 * t;
      _cameraChaseSpeed = min(
        maxSpeed,
        _cameraChaseSpeed + easeRate * easeIn * dt,
      );
    } else if (_cameraChaseSpeed > maxSpeed) {
      _cameraChaseSpeed = max(maxSpeed, _cameraChaseSpeed - easeRate * dt);
    }
  }

  void _clearKnockbackCameraAndFollow({bool snap = false}) {
    snapViewfinderToPlayer();
  }

  void setSpikeCurveStrength(double value) {
    spikeCurveStrength = value.clamp(0.0, 2.0);
    _applySpikeBehaviorToMounted();
  }

  void setSpikeChargeSpeed(double value) {
    spikeChargeSpeed = value.clamp(1.0, 2000.0);
    _applySpikeBehaviorToMounted();
  }

  void setSpikeBullRushSpeed(double value) {
    spikeBullRushSpeed = value.clamp(1.0, 3000.0);
    _applySpikeBehaviorToMounted();
  }

  void setSpikeChargeDuration(double value) {
    spikeChargeDuration = value.clamp(0.2, 10.0);
    _applySpikeBehaviorToMounted();
  }

  void setSpikeRushDistanceMultiplier(double value) {
    spikeRushDistanceMultiplier = value.clamp(1.0, 8.0);
    _applySpikeBehaviorToMounted();
  }

  void setSpikeMinRushDistance(double value) {
    spikeMinRushDistance = value.clamp(20.0, 4000.0);
    _applySpikeBehaviorToMounted();
  }

  void _applySpikeBehaviorToMounted() {
    for (final spike in universo.children.whereType<SpikeEnemy>()) {
      spike.configureBehavior(
        curveStrength: spikeCurveStrength,
        chargingSpeed: spikeChargeSpeed,
        bullRushSpeed: spikeBullRushSpeed,
        chargeDuration: spikeChargeDuration,
        rushDistanceMultiplier: spikeRushDistanceMultiplier,
        minRushDistance: spikeMinRushDistance,
      );
    }
  }

  void incrementShipsDestroyed() {
    shipsDestroyed++;
    scoreNotifier.value = shipsDestroyed;
  }

  void spawnEnemyExplosion(Vector2 worldPosition, Vector2 enemySize) {
    final radius = max(enemySize.x, enemySize.y) * 2;
    universo.add(SpaceExplosionEffect(center: worldPosition, radius: radius));
    playSfx('menu1.mp3');
  }

  /// Power-ups: sube el máximo de vida de la run y actualiza al jugador.
  /// Si [healCurrentByAmount] es true, suma [amount] a la vida actual (sin pasar del nuevo máximo).
  void extendPlayerMaxHitPoints(int amount, {bool healCurrentByAmount = true}) {
    if (amount <= 0) return;
    playerMaxHitPoints += amount;
    player.maxHitPoints = playerMaxHitPoints;
    if (healCurrentByAmount) {
      player.currentHitPoints = min(
        player.currentHitPoints + amount,
        playerMaxHitPoints,
      );
    } else {
      player.currentHitPoints = min(
        player.currentHitPoints,
        playerMaxHitPoints,
      );
    }
    hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
  }

  /// Rellena la vida actual al máximo conservando [playerMaxHitPoints] (power-ups).
  void refillPlayerCurrentHealthToMax() {
    player.maxHitPoints = playerMaxHitPoints;
    player.currentHitPoints = playerMaxHitPoints;
    hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
  }

  /// Nueva partida desde cero: vuelve el máximo al valor base (llamar desde menú / reset global si aplica).
  void resetPlayerMaxHitPointsToBase() {
    playerMaxHitPoints = basePlayerMaxHitPoints;
    if (player.isMounted) {
      player.maxHitPoints = playerMaxHitPoints;
      player.currentHitPoints = min(
        player.currentHitPoints,
        playerMaxHitPoints,
      );
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    //debugMode = true;
    pool = await FlameAudio.createPool(
      'fire_2.mp3',
      minPlayers: 1,
      maxPlayers: 3,
    );
    await _initSfx(['menu1.mp3', 'death1.mp3', 'menuOpen.mp3', 'alert3.mp3']);
    startBgmMusic();

    universo = World();
    add(universo);
    final layerFar = await ParallaxLayer.load(
      ParallaxImageData('stars3000x1500.png'), //estrellas1000x500dot.png
      repeat: ImageRepeat.repeat,
      velocityMultiplier: Vector2(0.5, 0.5),
    );

    final layerNear = await ParallaxLayer.load(
      ParallaxImageData('estrellas950x450.png'),
      repeat: ImageRepeat.repeat,
      velocityMultiplier: Vector2(1.2, 1.2),
    );

    final parallax = Parallax([
      layerFar,
      layerNear,
    ], baseVelocity: Vector2.zero());

    spaceParallax = ParallaxComponent(parallax: parallax);

    // Keep a fixed 1280×720 window into the world even if the canvas changes.
    camara = CameraComponent.withFixedResolution(
      width: logicalWidth,
      height: logicalHeight,
      world: universo,
      backdrop: spaceParallax,
      viewfinder: Viewfinder()
        ..anchor = Anchor.center
        ..zoom = cameraZoom,
    );
    add(camara!);

    player = Player(
      sprite: await Sprite.load('ship300x240.png'),
      position: Vector2(380, 380),
    );
    playerMaxHitPoints = basePlayerMaxHitPoints;
    player.maxHitPoints = playerMaxHitPoints;
    player.currentHitPoints = playerMaxHitPoints;
    universo.add(player);

    enemigo2 = RangedEnemy(
      sprite: await Sprite.load('verdePequeno.png'),
      position: Vector2(660, 380),
      size: Vector2(16, 16),
      maxHitPoints: 200,
      rotationSpeed: 3.0,
      bulletSpeed: 50,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo2);

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

    await _spawnEdgePatrolCrabs();

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

    hud = GameHud()..priority = 100;
    scoreNotifier.value = shipsDestroyed;
    camara?.viewport.add(OffscreenEnemyMarkers());
    camara?.viewport.add(hud);

    currentPlayerPos = player.position.clone();

    camara?.stop();
    _setViewfinderPosition(player.position);
  }

  /// Four patrol crabs just outside each viewport edge (16 total) to test markers.
  Future<void> _spawnEdgePatrolCrabs() async {
    final sprite = await Sprite.load('10.png');
    final origin = player.position;
    final half =
        _visibleWorldHalf() ??
        Vector2(
          logicalWidth / (2 * cameraZoom),
          logicalHeight / (2 * cameraZoom),
        );
    const outside = 150.0;
    const perSide = 4;
    const patrol = 80.0;

    List<double> spread(double from, double to, int n) {
      if (n <= 1) return [(from + to) / 2];
      return [for (var i = 0; i < n; i++) from + (to - from) * i / (n - 1)];
    }

    final alongY = spread(
      origin.y - half.y * 0.7,
      origin.y + half.y * 0.7,
      perSide,
    );
    final alongX = spread(
      origin.x - half.x * 0.7,
      origin.x + half.x * 0.7,
      perSide,
    );
    final leftX = origin.x - half.x - outside;
    final rightX = origin.x + half.x + outside;
    final topY = origin.y - half.y - outside;
    final bottomY = origin.y + half.y + outside;

    void addCrab(double x, double y) {
      universo.add(
        CrabEnemy(
          sprite: sprite,
          position: Vector2(x, y),
          size: Vector2(20, 20),
          maxHitPoints: 50,
          rotationSpeed: 4.0,
          damage: 30,
          patrolRadius: patrol,
        ),
      );
    }

    for (final y in alongY) {
      addCrab(leftX, y);
      addCrab(rightX, y);
    }
    for (final x in alongX) {
      addCrab(x, topY);
      addCrab(x, bottomY);
    }
  }

  @override
  void onRemove() {
    scoreNotifier.dispose(); // ✅ Importante: liberar recursos
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt * timeScale);
    _updateSpaceCamera(dt);
    _clampPlayerToViewport();

    currentPlayerPos.setFrom(player.position);

    final speed = player.currentSpeed.clamp(1.0, 10000.0);
    spaceParallax.parallax!.baseVelocity.setFrom(
      player.velocity * (25 / speed),
    );
  }

  @override
  void onMouseMove(flame_events.PointerHoverInfo info) {
    super.onMouseMove(info);
    if (!kIsWeb || cellularMode || camara == null || !hud.isLoaded) return;
    final worldTarget = camara!.globalToLocal(info.eventPosition.widget);
    hud.setWebMouseWorldTarget(worldTarget);
  }

  void _beginWebCharge() {
    if (!kIsWeb || cellularMode || paused || !player.isMounted || !hud.isLoaded) {
      return;
    }
    hud.beginCharge();
  }

  void _endWebCharge() {
    if (!kIsWeb || cellularMode || !hud.isLoaded) return;
    hud.releaseCharge();
  }

  @override
  void onPanDown(flame_events.DragDownInfo info) {
    super.onPanDown(info);
    if (cellularMode) return;
    _beginWebCharge();
    if (!kIsWeb || camara == null || !hud.isLoaded) return;
    hud.setWebMouseWorldTarget(
      camara!.globalToLocal(info.eventPosition.widget),
    );
  }

  @override
  void onPanUpdate(flame_events.DragUpdateInfo info) {
    super.onPanUpdate(info);
    if (!kIsWeb || cellularMode || camara == null || !hud.isLoaded) return;
    hud.setWebMouseWorldTarget(
      camara!.globalToLocal(info.eventPosition.widget),
    );
  }

  @override
  void onPanEnd(flame_events.DragEndInfo info) {
    super.onPanEnd(info);
    _endWebCharge();
  }

  @override
  void onGameResize(Vector2 size) {
    debugPrint('4. onGameResize (camera is $camara)');
    super.onGameResize(size);

    debugPrint("🔄 onGameResize - Tamaño: $size ");
  }

  void startBgmMusic() {
    FlameAudio.bgm.initialize();
    FlameAudio.bgm.play('bg_music.ogg');
  }

  void playShotSound(String file) {
    if (file == 'fire_2.mp3') {
      pool.start();
      return;
    }
    playSfx(file);
  }

  Future<void> _initSfx(List<String> files) async {
    unawaited(FlameAudio.audioCache.loadAll(files));
  }

  void playSfx(String file, {bool restart = true}) {
    unawaited(_playSfx(file, restart: restart));
  }

  Future<void> _playSfx(String file, {bool restart = true}) async {
    try {
      final player = _sfxPlayers.putIfAbsent(file, () {
        return AudioPlayer()..audioCache = FlameAudio.audioCache;
      });
      if (!restart && player.state == PlayerState.playing) return;
      await player.stop();
      await player.play(AssetSource(file), mode: PlayerMode.mediaPlayer);
    } catch (e, st) {
      debugPrint('SFX failed ($file): $e\n$st');
    }
  }

  void pauseBgmMusic() {
    FlameAudio.bgm.pause();
  }

  void resumeBgmMusic() {
    FlameAudio.bgm.resume();
  }

  // Método para pausar/reanudar
  void togglePause() {
    if (paused) {
      resumeEngine();
    } else {
      pauseEngine();
    }
  }

  // Método para verificar si hay GameOverComponent
  void removeGameOverComponent() {
    print('🧹 Buscando GameOverComponent...');

    if (camara?.viewport != null) {
      final gameOverComponents = camara!.viewport.children
          .whereType<GameOverComponent>()
          .toList();

      print('📊 Encontrados ${gameOverComponents.length} GameOverComponent(s)');

      for (final component in gameOverComponents) {
        component.removeFromParent();
        print('✅ GameOverComponent removido');
      }
    }

    // También buscar en los overlays
    if (overlays.isActive('GameOver')) {
      overlays.remove('GameOver');
      print('✅ Overlay GameOver removido');
    }
    if (overlays.isActive('ScoreTransmit')) {
      overlays.remove('ScoreTransmit');
    }
  }

  void deactivateAllEnemies() {
    int enemiesDeactivated = 0;
    if (universo.isMounted) {
      for (final enemy in universo.children.whereType<Enemigo>()) {
        if (enemy.isActivated) {
          enemy.deactivate();
          enemiesDeactivated++;
        } else {
          enemy.deactivate();
        }
      }
    }
    print('🛑 Enemigos desactivados: $enemiesDeactivated');
  }

  void clearEnemyBullets() {
    int removed = 0;
    if (universo.isMounted) {
      for (final component in universo.children.toList()) {
        if (component is EnemyBullet) {
          component.removeFromParent();
          removed++;
        }
      }
    }
    if (removed > 0) {
      print('🧹 EnemyBullet removidas: $removed');
    }
  }

  // Método para limpiar entidades
  void clearAllGameEntities() {
    int bulletsRemoved = 0;
    int explosionsRemoved = 0;

    // Limpiar balas y explosiones del universo
    if (universo.isMounted) {
      for (final component in universo.children.toList()) {
        // Aquí necesitarías importar las clases
        if (component is Bullet || component is EnemyBullet) {
          component.removeFromParent();
          bulletsRemoved++;
        } else if (component is ExplosionEffect) {
          component.removeFromParent();
          explosionsRemoved++;
        }
      }
    }
    print(
      '✅ Limpieza completada: $bulletsRemoved balas, $explosionsRemoved explosiones',
    );
  }

  // Método para resetear estadísticas del jugador
  void resetPlayerState() {
    player.maxHitPoints = playerMaxHitPoints;
    player.currentHitPoints = playerMaxHitPoints;
    player.position = Vector2(380, 380);
    player.isInvulnerable = false;
    player.isVisible = true;
    player.currentSpeed = 200;

    // Actualizar HUD
    if (hud != null) {
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
    }

    print('✅ Jugador reseteado');
  }

  // Método para resetear estadísticas del juego
  void resetGameStats() {
    print('📊 Reseteando estadísticas del juego...');

    shipsDestroyed = 0;
    scoreNotifier.value = 0;
    timeScale = 1.0;

    print('✅ Estadísticas reseteadas: score=0, timeScale=1.0');
  }

  // Método para resetear cámara
  void resetCamera() {
    print('🎥 Reseteando cámara...');

    if (camara != null) {
      cameraZoom = 0.5;
      camara!.viewfinder.zoom = cameraZoom;
      _clearKnockbackCameraAndFollow(snap: true);
      //camara!.snapTo(player.position);

      print('✅ Cámara reseteada: zoom=0.5x, siguiendo jugador');
    }
  }

  // Método para resetear HUD
  void resetHUD() {
    print('🖥️ Reseteando HUD...');

    if (hud != null) {
      hud.cancelCharge();
      // Resetear joysticks (solo existen en la versión app)
      hud.movementJoystick?.knob?.position =
          hud.movementJoystick?.background?.position ?? Vector2.zero();
      hud.lookJoystick?.knob?.position =
          hud.lookJoystick?.background?.position ?? Vector2.zero();

      // Actualizar barra de vida
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);

      print('✅ HUD reseteado');
    }
  }

  Future<void> recreatePlayer() async {
    print('👤 Recreando jugador...');

    if (hud.isLoaded) {
      hud.cancelCharge();
    }

    // Detener cualquier enemigo que estuviera disparando al jugador anterior
    deactivateAllEnemies();
    clearEnemyBullets();

    if (player.isMounted) {
      player.removeFromParent();
    }

    // 2. Crear nuevo jugador
    player = Player(
      sprite: await Sprite.load('ship.png'),
      position: Vector2(380, 380),
    );

    // 3. Misma run: conservar el máximo mejorado (power-ups), no el default del [Player].
    player.maxHitPoints = playerMaxHitPoints;
    player.currentHitPoints = playerMaxHitPoints;
    player.currentSpeed = 200;

    // 4. Añadir al universo
    universo.add(player);

    // 5. Actualizar referencias
    if (camara != null) {
      _clearKnockbackCameraAndFollow(snap: true);
    }

    if (hud != null) {
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
    }

    print('✅ Jugador recreado exitosamente');
  }
}
