import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

class GameButton extends PositionComponent with TapCallbacks, HasGameReference {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  bool _isPressed = false;
  late final TextComponent _textComponent;
  late final RectangleComponent _background;

  GameButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    required this.onPressed,
    this.backgroundColor = const Color(0xFF4A4E69),
    this.textColor = Colors.white,
    this.fontSize = 16.0,
    super.anchor = Anchor.center,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // Fondo del botón
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );

    // Borde exterior
    final border = RectangleComponent(
      size: Vector2(size.x + 4, size.y + 4),
      position: Vector2(-2, -2),
      paint: Paint()
        ..color = Colors.white.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Texto del botón
    _textComponent = TextComponent(
      text: text,
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.bold,
          fontFamily: 'Megatrans', // Cambia por tu fuente
        ),
      ),
    );

    addAll([_background, border, _textComponent]);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isPressed = true;
    _animatePress();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isPressed = false;
    _animateRelease();

    // Ejecutar acción después de animación
    Future.delayed(Duration(milliseconds: 100), onPressed);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isPressed = false;
    _animateRelease();
  }

  void _animatePress() {
    add(ScaleEffect.to(Vector2.all(0.95), EffectController(duration: 0.1)));

    _background.paint.color = backgroundColor.withAlpha(80);
  }

  void _animateRelease() {
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.1)));

    _background.paint.color = backgroundColor;
  }

  void setEnabled(bool enabled) {
    if (enabled) {
      add(OpacityEffect.to(1.0, EffectController(duration: 0.1)));
    } else {
      add(OpacityEffect.to(0.5, EffectController(duration: 0.1)));
      // Si está deshabilitado, no responder a toques
      // Podríamos remover TapCallbacks temporalmente
    }
  }
}
