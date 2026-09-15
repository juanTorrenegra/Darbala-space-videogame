import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/offscreen_tracked.dart';
import 'package:juanshooter/game.dart';

/// Gray edge triangles pointing at enemies outside the camera view.
class OffscreenEnemyMarkers extends PositionComponent
    with HasGameReference<MyGame> {
  static const double _edgePad = 20;
  static const double _triLen = 11;
  static const double _triHalf = 6.5;
  static const double _onScreenInset = 8;

  OffscreenEnemyMarkers()
    : super(
        anchor: Anchor.topLeft,
        priority: 90,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncSize();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncSize();
  }

  void _syncSize() {
    final viewSize =
        game.camara?.viewport.virtualSize ??
        Vector2(MyGame.logicalWidth, MyGame.logicalHeight);
    size = viewSize;
    position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cam = game.camara;
    if (cam == null || !game.universo.isMounted) return;

    final viewSize = cam.viewport.virtualSize;
    if (viewSize.x <= 0 || viewSize.y <= 0) return;
    final zoom = cam.viewfinder.zoom.clamp(0.01, 100.0);
    final worldCenter = cam.viewfinder.position;
    final screenCenter = viewSize / 2;
    final stroke = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    for (final target in game.universo.children.whereType<OffscreenTracked>()) {
      if (!target.isMounted) continue;
      final screen =
          screenCenter + (target.position - worldCenter) * zoom;
      if (_isOnScreen(screen, viewSize)) continue;

      final dir = screen - screenCenter;
      if (dir.length2 < 1e-8) continue;
      final edge = _clampToEdge(dir, screenCenter, viewSize);
      _drawTriangle(canvas, edge, atan2(dir.y, dir.x), stroke);
    }
  }

  bool _isOnScreen(Vector2 screen, Vector2 viewSize) {
    return screen.x >= _onScreenInset &&
        screen.x <= viewSize.x - _onScreenInset &&
        screen.y >= _onScreenInset &&
        screen.y <= viewSize.y - _onScreenInset;
  }

  Vector2 _clampToEdge(Vector2 dir, Vector2 center, Vector2 viewSize) {
    final halfW = viewSize.x / 2 - _edgePad;
    final halfH = viewSize.y / 2 - _edgePad;
    final tx = dir.x.abs() < 1e-8 ? 1e9 : halfW / dir.x.abs();
    final ty = dir.y.abs() < 1e-8 ? 1e9 : halfH / dir.y.abs();
    final t = min(tx, ty);
    return Vector2(center.x + dir.x * t, center.y + dir.y * t);
  }

  void _drawTriangle(Canvas canvas, Vector2 at, double angle, Paint stroke) {
    canvas.save();
    canvas.translate(at.x, at.y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(_triLen, 0)
      ..lineTo(-_triLen * 0.45, _triHalf)
      ..lineTo(-_triLen * 0.45, -_triHalf)
      ..close();
    canvas.drawPath(path, stroke);
    canvas.restore();
  }
}
