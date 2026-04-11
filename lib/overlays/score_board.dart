import 'package:flutter/material.dart';

import 'package:juanshooter/game.dart';

class ScoreBoard extends StatefulWidget {
  final MyGame game;

  const ScoreBoard({required this.game, super.key});

  @override
  State<ScoreBoard> createState() => _ScoreBoardState();
}

class _ScoreBoardState extends State<ScoreBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  int _currentScore = 0;
  bool _showMedalAnimation = false;

  static const double _baseFontSize = 36;

  /// Horizontal skew (radians-ish via Matrix4) for a slanted score panel.
  static const double _panelSkewX = -0.14;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _currentScore = widget.game.shipsDestroyed;
    widget.game.scoreNotifier.addListener(_onScoreChanged);
  }

  void _onScoreChanged() {
    final newScore = widget.game.scoreNotifier.value;

    setState(() {
      _currentScore = newScore;
    });

    _animationController.forward(from: 0.0);

    if (_currentScore % 10 == 0 && _currentScore > 0) {
      setState(() {
        _showMedalAnimation = true;
      });
    }
  }

  void _setupAnimations() {
    // 0.0–0.5: grow + cyan glow | 0.5–1.0: back to medium + calm
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_animationController);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showMedalAnimation = false;
        });
      }
    });
  }

  void onScoreUpdated(int newScore) {
    setState(() {
      _currentScore = newScore;
    });

    // Iniciar animación principal
    _animationController.forward(from: 0.0);

    // Lógica de medallas cada 10 puntos
    if (_currentScore % 10 == 0 && _currentScore > 0) {
      setState(() {
        _showMedalAnimation = true;
      });
    }
  }

  @override
  void dispose() {
    widget.game.scoreNotifier.removeListener(_onScoreChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 40,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return _buildScoreWithAnimations();
        },
      ),
    );
  }

  Widget _buildScoreWithAnimations() {
    final g = _glowAnimation.value;
    final borderAccent = Color.lerp(Colors.white24, Colors.cyanAccent, g)!;

    return Stack(
      children: [
        Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.center,
          child: Transform(
            transform: Matrix4.skewX(_panelSkewX),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(45 + (g * 35).round()),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.5 + g * 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.15 + 0.75 * g),
                    blurRadius: 6 + 48 * g,
                    spreadRadius: 1 + 14 * g,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentScore',
                    style: TextStyle(
                      fontSize: _baseFontSize,
                      fontFamily: 'steel700',
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.cyan.withOpacity(0.35 * g),
                          blurRadius: 4 + 18 * g,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showMedalAnimation) _buildMedalAnimation(),
      ],
    );
  }

  Widget _buildMedalAnimation() {
    return Positioned(
      right: -10,
      top: -10,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.yellow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('🏅', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
