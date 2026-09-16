import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/offscreen_tracked.dart';
import 'package:juanshooter/game.dart';

/// Edge trackers for targets outside the camera view: a globe holding a
/// portrait of the target, with a pointer wedge aimed at it.
class OffscreenEnemyMarkers extends PositionComponent
    with HasGameReference<MyGame> {
  /// Inset of the marker's globe center from the view edge. Has to clear the
  /// globe plus the pointer sticking out past it.
  static const double _edgePad = 34;

  /// Pointer wedge measured from the globe's rim outward.
  static const double _triLen = 14;
  static const double _triHalf = 8;
  static const double _onScreenInset = 8;

  /// Portrait size: half the target's on-screen size, kept in a range that
  /// suits the HUD so a big target cannot blow the marker up.
  static const double _iconMin = 14;
  static const double _iconMax = 30;

  /// Gap between the portrait and the globe's ring.
  static const double _globePad = 3;

  static const Color _lineColor = Color(0xFF9E9E9E);

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
      ..color = _lineColor
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
      final icon = (max(target.size.x, target.size.y) * zoom * 0.5).clamp(
        _iconMin,
        _iconMax,
      );
      _drawMarker(canvas, edge, atan2(dir.y, dir.x), target, icon, stroke);
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

  void _drawMarker(
    Canvas canvas,
    Vector2 at,
    double angle,
    OffscreenTracked target,
    double iconDiameter,
    Paint stroke,
  ) {
    final globe = iconDiameter / 2 + _globePad;
    canvas.save();
    canvas.translate(at.x, at.y);

    // Pointer wedge, rotated to face the target. Its base sits inside the
    // globe and is then cut away, leaving the globe's arc as its inner edge.
    canvas.save();
    canvas.rotate(angle);
    canvas.drawPath(_pointerPath(globe), stroke);
    canvas.drawPath(
      _innerPointerPath(globe),
      Paint()
        ..color = _lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Globe stays upright so the portrait is never drawn upside down.
    canvas.drawCircle(
      Offset.zero,
      globe,
      Paint()..color = const Color(0xCC0B1220),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: globe - 0.7)),
    );
    target.renderMarkerIcon(canvas, iconDiameter);
    canvas.restore();
    canvas.drawCircle(Offset.zero, globe, stroke);

    canvas.restore();
  }

  /// Wedge from the globe's rim outward, with the globe subtracted so its
  /// short base is replaced by a circular cut-out.
  Path _pointerPath(double globe) {
    final wedge = Path()
      ..moveTo(globe + _triLen, 0)
      ..lineTo(globe * 0.35, _triHalf)
      ..lineTo(globe * 0.35, -_triHalf)
      ..close();
    return Path.combine(
      PathOperation.difference,
      wedge,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: globe + 1)),
    );
  }

  /// Smaller wedge nested inside the pointer for a tracking-reticle look.
  Path _innerPointerPath(double globe) {
    final tipGap = _triLen * 0.3;
    return Path()
      ..moveTo(globe + _triLen - tipGap, 0)
      ..lineTo(globe + tipGap * 0.8, _triHalf * 0.34)
      ..lineTo(globe + tipGap * 0.8, -_triHalf * 0.34)
      ..close();
  }
}
