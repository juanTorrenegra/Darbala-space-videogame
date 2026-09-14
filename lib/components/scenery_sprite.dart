import 'package:flame/components.dart';

/// Marker component for level background scenery (planets, nebulae).
/// Lets the level system remove scenery when switching levels without
/// touching gameplay components.
class ScenerySprite extends SpriteComponent {
  ScenerySprite({
    required super.sprite,
    required super.position,
    required super.size,
    super.priority,
  }) : super(anchor: Anchor.center);
}
