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
import 'package:juanshooter/hud/game_hud.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:juanshooter/overlays/game_over.dart';
import 'package:juanshooter/overlays/informacion_juego.dart';
import 'package:juanshooter/weapons/bullet.dart';
import 'package:juanshooter/weapons/enemy_bullet.dart';
import 'package:juanshooter/effects/explosion_particles.dart';
//tamaño de pantalla = [796.363,392.727]
// juego: nave que elimina asteroides para encontrar armas para derrotar monstruos del espacio, escenario: dentro de un imperio y uno es un minero: mision: minar y mejorar la nave para poder acceder a MediumWorld y HardWorld, competir contra otros mineros compitiendo y compartiendo loot.

//prototipo

class MyGame extends FlameGame
    with
        HasGameReference<MyGame>,
        HasCollisionDetection,
        flame_events.MouseMovementDetector,
        flame_events.PanDetector {
  MyGame();

  /// Tope de vida al empezar una run nueva (menú / partida desde cero)
  static const int basePlayerMaxHitPoints = 100;

  /// Máximo de vida de la run: persiste al morir y al `recreatePlayer`; los power-ups lo aumentan.
  int playerMaxHitPoints = basePlayerMaxHitPoints;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int shipsDestroyed = 0;
  late Player player;
  late RangedEnemy mineroTorretas;
  late RangedEnemy enemigo1;
  late Enemigo enemigo2;
  late Enemigo enemigo3;
  late Enemigo enemigo4;
  late Enemigo enemigo5;
  late Enemigo enemigo6;
  late Enemigo enemigo7;
  late Enemigo enemigo8;

  late final GameHud hud;
  late final World universo;
  CameraComponent? camara;
  Vector2 currentPlayerPos = Vector2.zero();
  late AudioPool pool;
  double timeScale = 1.0; //game speed!
  double cameraZoom = 1.3;
  late InformacionJuego informacionJuego;

  late ParallaxComponent spaceParallax;

  // Método para cambiar la escala de tiempo
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

  void incrementShipsDestroyed() {
    shipsDestroyed++;
    scoreNotifier.value = shipsDestroyed;
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
  Future<void> onLoad() async {
    await super.onLoad();
    //debugMode = true;
    pool = await FlameAudio.createPool(
      'fire_2.mp3',
      minPlayers: 1,
      maxPlayers: 3,
    );
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
      velocityMultiplier: Vector2(2.2, 2.2),
    );

    final parallax = Parallax([
      layerFar,
      layerNear,
    ], baseVelocity: Vector2.zero());

    spaceParallax = ParallaxComponent(parallax: parallax);

    camara = CameraComponent(
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

    mineroTorretas = RangedEnemy(
      sprite: await Sprite.load('5.png'), //MINERO
      position: Vector2(1300, 400),
      size: Vector2(530, 300),
      maxHitPoints: 20,
      rotationSpeed: 0.4,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 40,
    );

    universo.add(mineroTorretas);

    enemigo1 = RangedEnemy(
      sprite: await Sprite.load('bite30x24.png'),
      position: Vector2(850, 400),
      size: Vector2(30, 24),
      maxHitPoints: 10,
      rotationSpeed: 3.0,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo1);

    enemigo2 = RangedEnemy(
      sprite: await Sprite.load('verdePequeno.png'),
      position: Vector2(440, 380),
      size: Vector2(16, 16),
      maxHitPoints: 10,
      rotationSpeed: 3.0,
      bulletSpeed: 50,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo2);

    enemigo6 = RangedEnemy(
      sprite: await Sprite.load('verdePequenoPink.png'), //
      position: Vector2(200, 390),
      size: Vector2(18, 16),
      rotationSpeed: 4.0,
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo6);

    enemigo7 = RangedEnemy(
      sprite: await Sprite.load('azulCanon.png'),
      position: Vector2(100, 440),
      size: Vector2(18, 16),
      rotationSpeed: 4.0,
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo7);

    enemigo8 = RangedEnemy(
      sprite: await Sprite.load('verdeMediano.png'),
      position: Vector2(350, 270),
      size: Vector2(30, 25),
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo8);

    enemigo4 = RangedEnemy(
      sprite: await Sprite.load('7B.png'),
      position: Vector2(750, 550),
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 10,
    );
    universo.add(enemigo4);

    enemigo5 = RangedEnemy(
      sprite: await Sprite.load('verdeGrande.png'),
      position: Vector2(380, 450),
      //size: Vector2(134, 199),
    );
    universo.add(enemigo5);

    hud = GameHud()..priority = 100;
    scoreNotifier.value = shipsDestroyed;
    camara?.viewport.add(hud);

    informacionJuego = InformacionJuego();
    informacionJuego.priority = 1000;
    if (camara?.viewport != null) {
      camara!.viewport.add(informacionJuego);
      informacionJuego.position = Vector2(10, size.y / 3);
    } //sin este if: la tabla se renderiza atras de los demas componentes

    currentPlayerPos = player.position.clone();

    camara?.follow(player);
  }

  // Método para mostrar/ocultar información
  void toggleGameInfo() {
    informacionJuego.toggleVisibility();
  }

  // Método para actualizar información específica
  void updateGameInfo() {
    // Se actualiza automáticamente en el update del componente
  }

  @override
  void onRemove() {
    scoreNotifier.dispose(); // ✅ Importante: liberar recursos
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt * timeScale);

    currentPlayerPos.setFrom(player.position);

    final input = hud.effectiveMovementDelta;

    if (input.length2 < 1e-10) {
      // Si no hay input (joystick / WASD en web), desaceleramos suavemente
      spaceParallax.parallax!.baseVelocity.scale(0.9);
      return;
    }

    // Capas en sentido contrario al movimiento del jugador (scroll del cielo).
    // Antes: `-input * 25` se veía como si las estrellas siguieran a la nave; usar `input * 25` invierte el scroll.
    spaceParallax.parallax!.baseVelocity = input * 25;
  }

  @override
  void onMouseMove(flame_events.PointerHoverInfo info) {
    super.onMouseMove(info);
    if (!kIsWeb || camara == null || !hud.isLoaded) return;
    final worldTarget = camara!.globalToLocal(info.eventPosition.widget);
    hud.setWebMouseWorldTarget(worldTarget);
  }

  @override
  void onPanDown(flame_events.DragDownInfo info) {
    super.onPanDown(info);
    if (!kIsWeb || paused || !player.isMounted) return;
    player.shoot();
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
      camara!.follow(player);
      //camara!.snapTo(player.position);

      print('✅ Cámara reseteada: zoom=0.5x, siguiendo jugador');
    }
  }

  // Método para resetear HUD
  void resetHUD() {
    print('🖥️ Reseteando HUD...');

    if (hud != null) {
      // Resetear joysticks
      hud.movementJoystick.knob?.position =
          hud.movementJoystick.background?.position ?? Vector2.zero();
      hud.lookJoystick.knob?.position =
          hud.lookJoystick.background?.position ?? Vector2.zero();

      // Actualizar barra de vida
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);

      print('✅ HUD reseteado');
    }
  }

  Future<void> recreatePlayer() async {
    print('👤 Recreando jugador...');

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
      camara!.follow(player);
    }

    if (hud != null) {
      hud.updateHealthBar(player.currentHitPoints, player.maxHitPoints);
    }

    print('✅ Jugador recreado exitosamente');
  }
}
