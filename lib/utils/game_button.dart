import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class GameButton extends PositionComponent with TapCallbacks, HasGameReference {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final bool textOnly;
  final double letterSpacing;

  late final TextComponent _textComponent;
  RectangleComponent? _background;

  GameButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    required this.onPressed,
    this.backgroundColor = const Color(0xFF4A4E69),
    this.textColor = Colors.white,
    this.fontSize = 16.0,
    this.textOnly = false,
    this.letterSpacing = 0,
    super.anchor = Anchor.center,
  }) : super(position: position, size: size);

  static List<Shadow> _cyanTextGlow() => [
        Shadow(
          color: Colors.cyanAccent.withOpacity(0.95),
          blurRadius: 14,
        ),
        Shadow(
          color: Colors.cyan.withOpacity(0.65),
          blurRadius: 22,
        ),
      ];

  @override
  Future<void> onLoad() async {
    _textComponent = TextComponent(
      text: text,
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.bold,
          fontFamily: 'Megatrans',
          letterSpacing: letterSpacing,
          shadows: textOnly ? _cyanTextGlow() : null,
        ),
      ),
    );

    if (textOnly) {
      add(_textComponent);
      return;
    }

    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );

    final border = RectangleComponent(
      size: Vector2(size.x + 4, size.y + 4),
      position: Vector2(-2, -2),
      paint: Paint()
        ..color = Colors.white.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    addAll([_background!, border, _textComponent]);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _animatePress();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _animateRelease();

    Future.delayed(const Duration(milliseconds: 100), onPressed);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _animateRelease();
  }

  void _animatePress() {
    add(ScaleEffect.to(Vector2.all(0.95), EffectController(duration: 0.1)));

    if (_background != null) {
      _background!.paint.color = backgroundColor.withAlpha(80);
    }
  }

  void _animateRelease() {
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.1)));

    if (_background != null) {
      _background!.paint.color = backgroundColor;
    }
  }

  void setEnabled(bool enabled) {
    if (enabled) {
      add(OpacityEffect.to(1.0, EffectController(duration: 0.1)));
    } else {
      add(OpacityEffect.to(0.5, EffectController(duration: 0.1)));
    }
  }
}
