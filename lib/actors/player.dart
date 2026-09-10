import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/effects/charge_aim_effect.dart';
import 'package:juanshooter/effects/explosion_particles.dart';
import 'package:juanshooter/effects/thruster_trail.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/hud/potency_bar.dart';
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
  double currentSpeed = 50;
  double _angle = 0;
  bool _isChargeSlowed = false;
  double _speedBeforeCharge = 50;
  final Vector2 _knockbackRemaining = Vector2.zero();
  double knockbackSpeed = 120;

  /// Current space-drift velocity (world units per second).
  final Vector2 velocity = Vector2.zero();

  /// Seconds to reach [currentSpeed] from a standstill.
  double accelTime = 2.0;

  /// Seconds to coast to a stop after releasing thrust.
  double coastTime = 1.2;

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
  ThrusterTrail? _trail;

  void takeDamage(int damage) {    if (isInvulnerable || _isDying) return;

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

  void applyChargeSlowdown() {
    if (_isChargeSlowed || _isDying) return;
    _speedBeforeCharge = currentSpeed;
    currentSpeed = (currentSpeed - ChargeShot.speedPenalty).clamp(
      1.0,
      currentSpeed,
    );
    _isChargeSlowed = true;
  }

  void restoreChargeSpeed() {
    if (!_isChargeSlowed) return;
    currentSpeed = _speedBeforeCharge;
    _isChargeSlowed = false;
  }

  void startKnockback(Vector2 delta, {double? speed}) {
    if (_isDying || delta.length2 <= 0) return;
    _knockbackRemaining.setFrom(delta);
    if (speed != null) {
      knockbackSpeed = speed;
    }
  }

  void clearKnockback() {
    _knockbackRemaining.setZero();
  }

  void clearVelocity() {
    velocity.setZero();
  }

  /// Keeps the ship inside the visible camera rectangle and kills slide into the walls.
  void containInWorldRect({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    if (position.x < minX) {
      position.x = minX;
      if (velocity.x < 0) velocity.x = 0;
      if (_knockbackRemaining.x < 0) _knockbackRemaining.x = 0;
    } else if (position.x > maxX) {
      position.x = maxX;
      if (velocity.x > 0) velocity.x = 0;
      if (_knockbackRemaining.x > 0) _knockbackRemaining.x = 0;
    }
    if (position.y < minY) {
      position.y = minY;
      if (velocity.y < 0) velocity.y = 0;
      if (_knockbackRemaining.y < 0) _knockbackRemaining.y = 0;
    } else if (position.y > maxY) {
      position.y = maxY;
      if (velocity.y > 0) velocity.y = 0;
      if (_knockbackRemaining.y > 0) _knockbackRemaining.y = 0;
    }
  }

  void _steerVelocityToward(Vector2 target, double rate, double dt) {
    final delta = target - velocity;
    final distance = delta.length;
    final maxStep = rate * dt;
    if (distance <= maxStep) {
      velocity.setFrom(target);
      return;
    }
    velocity.add(delta.normalized() * maxStep);
  }

  void _updateSpaceMovement(double dt) {
    final move = game.hud.effectiveMovementDelta;
    final maxSpeed = currentSpeed.clamp(1.0, 10000.0);

    if (move.length2 > 0.0001) {
      final accel = maxSpeed / accelTime.clamp(0.05, 20.0);
      _steerVelocityToward(move * maxSpeed, accel, dt);
    } else {
      final decel = maxSpeed / coastTime.clamp(0.05, 30.0);
      _steerVelocityToward(Vector2.zero(), decel, dt);
    }

    if (velocity.length > maxSpeed) {
      velocity.scale(maxSpeed / velocity.length);
    }

    if (velocity.length2 > 1e-8) {
      position.add(velocity * dt);
    }
  }

  void _updateKnockback(double dt) {
    if (_knockbackRemaining.length2 < 1e-8) return;
    final remaining = _knockbackRemaining.length;
    final step = knockbackSpeed * dt;
    if (step >= remaining) {
      position.add(_knockbackRemaining);
      _knockbackRemaining.setZero();
      return;
    }
    final dir = _knockbackRemaining.normalized();
    position.add(dir * step);
    _knockbackRemaining.scale((remaining - step) / remaining);
  }

  void die() {
    if (_isDying) return; // ✅ Evitar múltiples llamadas

    _isDying = true;
    restoreChargeSpeed();
    clearKnockback();
    clearVelocity();
    _trail?.clear();
    if (game.hud.isLoaded) {
      game.hud.cancelCharge();
    }
    print("Player died! Starting death sequence...");

    // ✅ Detener enemigos activos y limpiar balas enemigas para el reset
    game.deactivateAllEnemies();
    game.clearEnemyBullets();

    _createExplosion();
    game.playSfx('death1.mp3');

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
    final radius = max(size.x, size.y) * 4;
    game.universo.add(
      SpaceExplosionEffect(
        center: position.clone(),
        radius: radius,
        durationScale: 3,
        rippleCount: 2,
        rippleSpeed: 55,
      ),
    );
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
    restoreChargeSpeed();
    currentSpeed = 50;

    clearKnockback();
    clearVelocity();
    _trail?.clear();

    // Restaurar posición y rotación
    position = Vector2(380, 380);
    angle = 0;
    _angle = 0;

    print('🔄 Jugador reseteado completamente');
  }

  @override
  void onRemove() {
    _trail?.removeFromParent();
    _trail = null;
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    add(CircleHitbox()..collisionType = CollisionType.active);
    game.universo.add(ChargeAimEffect());
    _trail = ThrusterTrail(player: this);
    game.universo.add(_trail!);
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
      _updateKnockback(dt);
      _updateSpaceMovement(dt);

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

  void shoot({
    int damage = 4,
    double sizeScale = 1,
    String sfx = 'fire_2.mp3',
  }) {
    if (_isDying) return;
    final shootPosition = calculateShootPosition(
      position,
      angle,
      size,
      10.0, // Offset adicional desde el borde
    );

    final bullet = Bullet(
      position: shootPosition,
      angle: angle,
      speed: 100,
      damage: damage,
      sizeScale: sizeScale,
    );
    game.universo.add(bullet);
    game.playShotSound(sfx);
  }
}
