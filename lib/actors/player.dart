import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/effects/explosion_particles.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/overlays/game_over.dart';
import 'package:juanshooter/weapons/bullet.dart';
import 'package:juanshooter/utils/game_utils.dart';

class Player extends SpriteComponent with HasGameReference<MyGame> {
  Player({required Sprite sprite, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(28),
        anchor: Anchor.center,
        sprite: sprite,
        priority: 8,
      );
  //double _baseSpeed = 80;;
  double currentSpeed = 100;
  double _angle = 0;

  /// Valores por defecto; [MyGame] asigna `playerMaxHitPoints` al cargar / recrear.
  int maxHitPoints = 100;
  int currentHitPoints = 100;
  bool isInvulnerable = false;
  double invulnerabilityTime = 2.0; // ✅ 2 segundos de invulnerabilidad
  double invulnerabilityTimer = 0;
  double blinkTimer = 0;
  bool isVisible = true;
  double blinkInterval = 0.1; // ✅ Parpadeo cada 0.1 segundos

  // ✅ Variables para la secuencia de muerte
  bool _isDying = false;
  double _deathTimer = 0;
  double _deathDuration = 2.0;
  double _originalTimeScale = 1.0;

  // Método para recibir daño
  void takeDamage(int damage) {
    if (isInvulnerable || _isDying) return;

    currentHitPoints -= damage;

    // Activar invulnerabilidad temporal
    isInvulnerable = true;
    invulnerabilityTimer = invulnerabilityTime;
    blinkTimer = blinkInterval;
    isVisible = false; // Comenzar invisible para el primer parpadeo

    // Notificar al HUD que actualice la barra de vida
    game.hud.updateHealthBar(currentHitPoints, maxHitPoints);

    // Verificar si el jugador murió
    if (currentHitPoints <= 0) {
      die();
    }
  }

  // Método para curar
  void heal(int amount) {
    currentHitPoints = min(currentHitPoints + amount, maxHitPoints);
    game.hud.updateHealthBar(currentHitPoints, maxHitPoints);
  }

  void die() {
    if (_isDying) return; // ✅ Evitar múltiples llamadas

    _isDying = true;
    print("Player died! Starting death sequence...");

    // ✅ Detener enemigos activos y limpiar balas enemigas para el reset
    game.deactivateAllEnemies();
    game.clearEnemyBullets();

    _createExplosion();

    print('🎮 Programando GameOverComponent en 1.5 segundos...');

    Future.delayed(Duration(milliseconds: 1500), () {
      print('🎮 Intentando añadir GameOverComponent...');
      print('🎮 isDying: $_isDying');
      print('🎮 isMounted: $isMounted');
      print('🎮 game.camara: ${game.camara}');
      print('🎮 game.camara?.viewport: ${game.camara?.viewport}');

      if (_isDying && isMounted) {
        if (game.camara != null && game.camara!.viewport.isMounted) {
          print('🎮 Creando GameOverComponent...');
          final gameOver = GameOverComponent();

          // Añadir logs del constructor
          print('🎮 GameOverComponent creado');
          print('🎮 Prioridad: ${gameOver.priority}');

          // Añadir listener para cuando se cargue
          gameOver
              .onLoad()
              .then((_) {
                print('🎮 GameOverComponent cargado exitosamente');
                print('🎮 Tamaño asignado: ${gameOver.size}');
              })
              .catchError((error) {
                print('❌ Error cargando GameOverComponent: $error');
              });

          game.camara!.viewport.add(gameOver);
          print('✅ GameOverComponent añadido al viewport');

          // Verificar que se añadió
          Future.delayed(Duration(milliseconds: 100), () {
            print(
              '🎮 Componentes en viewport después de añadir: ${game.camara!.viewport.children.length}',
            );
            final gameOverComponents = game.camara!.viewport.children
                .whereType<GameOverComponent>()
                .toList();
            print(
              '🎮 GameOverComponents encontrados: ${gameOverComponents.length}',
            );
          });
        } else {
          print(
            '❌ No se puede añadir GameOverComponent: cámara o viewport no disponibles',
          );
          print('❌ game.camara: ${game.camara}');
          print('❌ viewport.isMounted: ${game.camara?.viewport?.isMounted}');
        }
      } else {
        print('❌ Condiciones no cumplidas para añadir GameOverComponent');
        print('❌ _isDying: $_isDying');
        print('❌ isMounted: $isMounted');
      }
    });
  }

  void _createExplosion() {
    final explosion = ExplosionEffect(
      center: position.clone(),
      particleCount: 30, // ✅ Muchas partículas
      explosionRadius: 20, // ✅ Área grande de explosión
      duration: _deathDuration,
    );

    game.universo.add(explosion);
  }

  void _completeDeathSequence() {
    // ✅ Restaurar escala de tiempo normal
    game.timeScale = _originalTimeScale;
    //game.overlays.add('MainMenu');

    print("Death sequence completed");
  }

  void resetPlayer() {
    // Cancelar cualquier secuencia de muerte
    _isDying = false;
    _deathTimer = 0;

    // Restaurar hitpoints
    currentHitPoints = maxHitPoints;

    // Restaurar estado
    isInvulnerable = false;
    isVisible = true;

    // Restaurar velocidad
    currentSpeed = 80;

    // Restaurar posición y rotación
    position = Vector2(380, 380);
    angle = 0;
    _angle = 0;

    print('🔄 Jugador reseteado completamente');
  }

  @override
  Future<void> onLoad() async {
    add(CircleHitbox()..collisionType = CollisionType.active);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isDying) {
      _deathTimer += dt;

      // ✅ Completar la secuencia después de 3 segundos (en tiempo real)
      if (_deathTimer >= _deathDuration) {
        _completeDeathSequence();
        removeFromParent(); // ✅ Eliminar el jugador del juego
        return;
      }
    }

    // ✅ Solo actualizar movimiento si no está muriendo
    if (!_isDying) {
      // Manejar invulnerabilidad y parpadeo
      if (isInvulnerable) {
        invulnerabilityTimer -= dt;
        blinkTimer -= dt;

        if (blinkTimer <= 0) {
          isVisible = !isVisible;
          blinkTimer = blinkInterval;
        }

        if (invulnerabilityTimer <= 0) {
          isInvulnerable = false;
          isVisible = true;
        }
      }

      // Movement: joystick; en web también WASD (ver [GameHud.effectiveMovementDelta]).
      final move = game.hud.effectiveMovementDelta;
      if (move.length2 > 0) {
        position.add(move * currentSpeed * dt);
      }

      // Rotación: look joystick; en web también sigue al mouse
      final look = game.hud.effectiveLookDelta;
      if (look.length2 > 0) {
        _angle = look.screenAngle();
        const double offset = -pi / 2; // Ajusta este valor según tu sprite
        angle = _angle + offset;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Solo renderizar si es visible durante el parpadeo
    if (isVisible && !_isDying) {
      super.render(canvas);
    }
  }

  void shoot() {
    if (_isDying) return;
    final shootPosition = calculateShootPosition(
      position,
      angle,
      size,
      10.0, // Offset adicional desde el borde
    );

    final bullet = Bullet(position: shootPosition, angle: angle, speed: 100);
    game.universo.add(bullet);
    game.pool.start();
  }
}
