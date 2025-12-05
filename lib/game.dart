import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/actors/enemigo.dart';
import 'package:juanshooter/actors/player.dart';
import 'package:juanshooter/actors/ranged_enemy.dart';
import 'package:juanshooter/hud/game_hud.dart';
import 'package:flame_audio/flame_audio.dart';
//tamaño de pantalla = [796.3636474609375,392.7272644042969]
// juego: nave que elimina asteroides para encontrar armas para derrotar monstruos del espacio, escenario: dentro de un imperio y uno es un minero: mision: minar y mejorar la nave para poder acceder a MediumWorld y HardWorld, competir contra otros mineros compitiendo y compartiendo loot.

//prototipo

class MyGame extends FlameGame
    with HasGameReference<MyGame>, HasCollisionDetection {
  MyGame();

  late final Player player;
  late final RangedEnemy mineroTorretas;
  late final RangedEnemy enemigo1;
  late final Enemigo enemigo2;
  late final Enemigo enemigo3;
  late final Enemigo enemigo4;
  late final Enemigo enemigo5;

  late final GameHud hud;
  late final World universo;
  CameraComponent? camara;
  Vector2 currentPlayerPos = Vector2.zero();
  late AudioPool pool;
  double timeScale = 1.0;

  int shipsDestroyed = 0;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

  void incrementShipsDestroyed() {
    shipsDestroyed++;
    //hud.updateShipsDestroyed(shipsDestroyed); contador anterior
    scoreNotifier.value = shipsDestroyed;
  }

  void fast() {
    // Llama al método del player
    player.toggleFastMode(!player.isFastMode); // Alternar estado
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

    camara = CameraComponent(
      world: universo,
      viewfinder: Viewfinder()..anchor = Anchor.center,
    );
    //camara?.viewfinder.anchor = Anchor.center;
    add(camara!);

    final background = SpriteComponent(
      sprite: await Sprite.load('b.png'), //Nebula3.png b.png
      size: Vector2(6000, 3000),
      anchor: Anchor.topLeft,
      position: Vector2(0, 0),
    )..priority = -100;
    universo.add(background);

    player = Player(
      sprite: await Sprite.load('ship.png'), // SIMULAR RELOAD LASERS
      position: Vector2(380, 380),
    );
    player.maxHitPoints = 10;
    player.currentHitPoints = 10;
    universo.add(player);

    mineroTorretas = RangedEnemy(
      sprite: await Sprite.load('5.png'), //MINERO
      position: Vector2(100, 100),
      size: Vector2(530, 300),
      maxHitPoints: 20,
      rotationSpeed: 0.4,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 5,
    );

    universo.add(mineroTorretas);

    enemigo1 = RangedEnemy(
      sprite: await Sprite.load('bite30x24.png'), //IZQUIERDA
      position: Vector2(850, 400),
      size: Vector2(30, 24),
      maxHitPoints: 10,
      rotationSpeed: 3.0,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 2,
    );
    universo.add(enemigo1);

    enemigo2 = RangedEnemy(
      sprite: await Sprite.load('bite30x24.png'), //morado
      position: Vector2(850, 300),
      size: Vector2(30, 24),
      maxHitPoints: 10,
      rotationSpeed: 3.0,
      bulletSpeed: 50,
      shootingThreshold: 30,
      damage: 1,
    );
    universo.add(enemigo2);

    enemigo3 = RangedEnemy(
      sprite: await Sprite.load('3B.png'), //derecha
      position: Vector2(850, 450),
      size: Vector2(30, 24),
      rotationSpeed: 4.0,
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 1,
    );
    universo.add(enemigo3);

    enemigo4 = RangedEnemy(
      sprite: await Sprite.load('7B.png'),
      position: Vector2(750, 550),
      maxHitPoints: 10,
      bulletSpeed: 100,
      shootingThreshold: 30,
      damage: 1,
    );
    universo.add(enemigo4);

    enemigo5 = RangedEnemy(
      sprite: await Sprite.load('2B.png'),
      position: Vector2(380, 450),
      //size: Vector2(134, 199),
    );
    universo.add(enemigo5);

    hud = GameHud()..priority = 100;
    scoreNotifier.value = shipsDestroyed;
    camara?.viewport.add(hud);

    currentPlayerPos = player.position.clone();

    camara?.follow(player);
  }

  @override
  void onRemove() {
    scoreNotifier.dispose(); // ✅ Importante: liberar recursos
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    super.update(dt * timeScale);
    // Actualizar posición de depuración
    currentPlayerPos.setFrom(player.position);
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
}
