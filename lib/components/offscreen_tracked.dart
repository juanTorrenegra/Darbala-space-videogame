import 'dart:ui';

import 'package:flame/components.dart';

/// Marks a component that the offscreen edge markers should point at,
/// so the player can find targets outside the camera view.
mixin OffscreenTracked on PositionComponent {
  /// Draws a small portrait of this target inside the marker's globe.
  ///
  /// The canvas origin is the globe's center and is not rotated, so the
  /// portrait always reads upright no matter which way the pointer faces.
  /// Draw centered on the origin, fitting inside a [diameter] box.
  void renderMarkerIcon(Canvas canvas, double diameter);
}
