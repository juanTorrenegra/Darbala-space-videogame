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
  late Animation<Color?> _colorAnimation;
  late Animation<double> _glowAnimation;

  int _currentScore = 0;
  bool _showMedalAnimation = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _currentScore = widget.game.shipsDestroyed;
    // ✅ ESCUCHAR CAMBIOS DEL SCORE
    widget.game.scoreNotifier.addListener(_onScoreChanged);
  }

  // ✅ NUEVO: Método que se ejecuta cuando cambia el score
  void _onScoreChanged() {
    final newScore = widget.game.scoreNotifier.value;

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

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.purpleAccent,
    ).animate(_animationController);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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
    _animationController.dispose(); // ✅ IMPORTANTE: liberar recursos
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
    return Stack(
      children: [
        // Score Box Principal
        Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getBorderColorForScore(),
                width: 2 + _glowAnimation.value * 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getGlowColorForScore().withOpacity(
                    _glowAnimation.value * 0.5,
                  ),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de nave destruida
                //Icon(
                //  Icons.rocket_launch,
                //  color: _colorAnimation.value,
                //  size: 24,
                //),
                //const SizedBox(width: 8),
                Text(
                  '$_currentScore',
                  style: TextStyle(
                    fontSize: 36,
                    fontFamily: 'steel700.ttf',
                    color: _colorAnimation.value,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.purpleAccent.withOpacity(
                          _glowAnimation.value,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Animación de medalla (cuando corresponde)
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
        child: Text('🏅', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Color _getBorderColorForScore() {
    if (_currentScore >= 20) return Colors.cyan;
    if (_currentScore >= 10) return Colors.purpleAccent;
    return Colors.blue;
  }

  Color _getGlowColorForScore() {
    if (_currentScore >= 20) return Colors.cyan;
    if (_currentScore >= 10) return Colors.purpleAccent;
    return Colors.blue;
  }

  void _triggerMedalAnimation() {
    // Animación especial para medallas
  }
}
