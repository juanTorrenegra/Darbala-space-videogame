import 'package:flame/components.dart';
import 'package:juanshooter/weapons/bullet.dart';
import 'package:juanshooter/weapons/procedural_shots.dart';

enum AmmoKind {
  laser,
  needle,
  plasma,
  ion;

  PositionComponent spawn({
    required Vector2 position,
    required double angle,
    required int damage,
    double sizeScale = 1,
  }) {
    switch (this) {
      case AmmoKind.laser:
        return Bullet(
          position: position,
          angle: angle,
          speed: 100,
          damage: damage,
          sizeScale: sizeScale,
        );
      case AmmoKind.needle:
        return NeedleShot(
          position: position,
          angle: angle,
          speed: 260,
          damage: damage,
          sizeScale: sizeScale,
        );
      case AmmoKind.plasma:
        return PlasmaBolt(
          position: position,
          angle: angle,
          speed: 80,
          damage: damage,
          sizeScale: sizeScale,
        );
      case AmmoKind.ion:
        return IonRing(
          position: position,
          angle: angle,
          speed: 130,
          damage: damage,
          sizeScale: sizeScale,
        );
    }
  }
}
