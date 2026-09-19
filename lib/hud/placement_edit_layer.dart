import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/components/placement_edit_mode.dart';
import 'package:juanshooter/game.dart';

/// Viewport overlay that applies the armed tool to the selected sprite only.
///
/// It ignores the joystick / shoot / tool-button regions so those keep working.
class PlacementEditLayer extends PositionComponent
    with DragCallbacks, ScaleCallbacks, HasGameReference<MyGame> {
  PlacementEditLayer() : super(priority: 110, anchor: Anchor.topLeft);

  double _pinchBaseScale = 1;
  double _dragBaseScale = 1;
  Vector2 _dragStartFromCenter = Vector2.zero();

  bool get _armed {
    final selected = game.selectedPlacement;
    return selected != null &&
        selected.isMounted &&
        game.placementEditMode != PlacementEditMode.none;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!_armed) return false;
    if (_inHudDeadZone(point)) return false;
    return super.containsLocalPoint(point);
  }

  bool _inHudDeadZone(Vector2 point) {
    final view = size;
    final stick = Vector2(view.x * 1 / 8, view.y * 3 / 4);
    final shoot = Vector2(view.x * 7 / 8, view.y * 3 / 4);
    if (point.distanceTo(stick) < 100) return true;
    if (point.distanceTo(shoot) < 100) return true;
    // Tool cluster sits above the right stick / shoot pad.
    if (point.x > view.x - 140 &&
        point.y > view.y * 3 / 4 - 220 &&
        point.y < view.y * 3 / 4 - 80) {
      return true;
    }
    // Menu letter at the bottom center.
    if ((point - Vector2(view.x / 2, view.y - 40)).length < 50) return true;
    return false;
  }

  Vector2? _spriteScreenCenter() {
    final selected = game.selectedPlacement;
    final cam = game.camara;
    if (selected == null || cam == null) return null;
    final zoom = cam.viewfinder.zoom.clamp(0.01, 100.0);
    return size / 2 + (selected.position - cam.viewfinder.position) * zoom;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.suppressHudShoot = true;
    final selected = game.selectedPlacement;
    if (selected == null) return;
    _dragBaseScale = selected.scale.x;
    final center = _spriteScreenCenter();
    if (center != null) {
      _dragStartFromCenter = event.localPosition - center;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final selected = game.selectedPlacement;
    final cam = game.camara;
    if (selected == null || cam == null) return;
    final zoom = cam.viewfinder.zoom.clamp(0.01, 100.0);

    switch (game.placementEditMode) {
      case PlacementEditMode.position:
        selected.position.add(event.localDelta / zoom);
      case PlacementEditMode.scale:
        final center = _spriteScreenCenter();
        if (center == null) return;
        final from = _dragStartFromCenter;
        if (from.length2 < 16) {
          selected.setUniformScale(
            selected.scale.x * (1 - event.localDelta.y * 0.008),
          );
          return;
        }
        final now = event.localEndPosition;
        if (now.x.isNaN || now.y.isNaN) return;
        final ratio = (now - center).length / from.length;
        selected.setUniformScale(_dragBaseScale * ratio);
      case PlacementEditMode.rotate:
        final center = _spriteScreenCenter();
        if (center == null) return;
        final start = event.localStartPosition;
        final end = event.localEndPosition;
        if (end.x.isNaN || end.y.isNaN) return;
        final a0 = atan2(start.y - center.y, start.x - center.x);
        final a1 = atan2(end.y - center.y, end.x - center.x);
        selected.angle += a1 - a0;
      case PlacementEditMode.none:
        break;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.suppressHudShoot = false;
  }

  @override
  void onScaleStart(ScaleStartEvent event) {
    super.onScaleStart(event);
    game.suppressHudShoot = true;
    _pinchBaseScale = game.selectedPlacement?.scale.x ?? 1;
  }

  @override
  void onScaleUpdate(ScaleUpdateEvent event) {
    final selected = game.selectedPlacement;
    if (selected == null) return;
    if (game.placementEditMode == PlacementEditMode.scale &&
        event.pointerCount >= 2) {
      selected.setUniformScale(_pinchBaseScale * event.scale);
      return;
    }
    if (game.placementEditMode == PlacementEditMode.position) {
      final cam = game.camara;
      if (cam == null) return;
      selected.position.add(
        event.localDelta / cam.viewfinder.zoom.clamp(0.01, 100.0),
      );
    }
  }

  @override
  void onScaleEnd(ScaleEndEvent event) {
    super.onScaleEnd(event);
    game.suppressHudShoot = false;
  }
}
