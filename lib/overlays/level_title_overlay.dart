import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Drives a [LevelTitleOverlay] sequence from game code.
///
/// Timeline (seconds):
/// - 0.0–0.9: blur fades in, title enters (scale + letter-spacing + fade)
/// - 1.9:     one small fast glitch burst
/// - 3.9:     three consecutive glitch bursts
/// - 5.2–5.8: fade to full black → [blackout] completes
/// - then the game holds the black screen, loads the next level, and calls
///   [requestDismiss] → black fades out → [finished] completes.
class LevelTitleController {
  LevelTitleController({required this.title});

  final String title;

  final Completer<void> _blackout = Completer<void>();
  final Completer<void> _finished = Completer<void>();

  /// Completes when the screen is fully black.
  Future<void> get blackout => _blackout.future;

  /// Completes when the black fade-out finished and the overlay can go.
  Future<void> get finished => _finished.future;

  bool _dismissRequested = false;
  bool get dismissRequested => _dismissRequested;

  void requestDismiss() {
    _dismissRequested = true;
  }

  void completeBlackout() {
    if (!_blackout.isCompleted) _blackout.complete();
  }

  void completeFinished() {
    if (!_finished.isCompleted) _finished.complete();
  }
}

/// Full-screen level title card: blurred game view, huge animated title,
/// glitch bursts, then a fade to black. Driven by a [LevelTitleController].
class LevelTitleOverlay extends StatefulWidget {
  const LevelTitleOverlay({required this.controller, super.key});

  final LevelTitleController controller;

  @override
  State<LevelTitleOverlay> createState() => _LevelTitleOverlayState();
}

class _LevelTitleOverlayState extends State<LevelTitleOverlay>
    with TickerProviderStateMixin {
  static const double _mainSeconds = 5.8;

  late final AnimationController _main = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5800),
  )..forward();

  late final AnimationController _dismiss = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Timer? _dismissPoll;

  @override
  void initState() {
    super.initState();
    _main.addListener(() {
      if (_main.isCompleted) {
        widget.controller.completeBlackout();
      }
    });
    _dismiss.addListener(() {
      if (_dismiss.isCompleted) {
        widget.controller.completeFinished();
      }
    });
    _dismissPoll = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (widget.controller.dismissRequested &&
          !_dismiss.isAnimating &&
          !_dismiss.isCompleted) {
        _dismiss.forward();
      }
    });
  }

  @override
  void dispose() {
    _dismissPoll?.cancel();
    _main.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  static bool _inWindow(double t, double start, double length) {
    return t >= start && t <= start + length;
  }

  /// One small glitch ~1 s after the title settles, then three consecutive
  /// glitches 2 s later.
  static bool _isGlitching(double t) {
    return _inWindow(t, 1.9, 0.25) ||
        _inWindow(t, 3.9, 0.18) ||
        _inWindow(t, 4.25, 0.18) ||
        _inWindow(t, 4.6, 0.18);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_main, _dismiss]),
      builder: (context, _) {
        final t = _main.value * _mainSeconds;

        // Blur fade-in over the first half second.
        final blurSigma = (t / 0.5).clamp(0.0, 1.0) * 6;

        // Title entrance: fade + scale down + letter-spacing tighten.
        final entrance = ((t - 0.15) / 0.55).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(entrance);
        final titleOpacity = eased;
        final titleScale = 1.25 - 0.25 * eased;
        final letterSpacing = 26 - 16 * eased;

        final glitching = _isGlitching(t);

        // Fade to black, then back out when dismissed.
        var black = ((t - 5.2) / 0.6).clamp(0.0, 1.0);
        black *= 1 - _dismiss.value;

        return Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred game view (same trick as the main menu).
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                      ),
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.25 * (blurSigma / 6),
                        ),
                      ),
                    ),
                  ),

                  // Title.
                  Center(
                    child: _buildTitle(
                      t,
                      glitching,
                      titleOpacity,
                      titleScale,
                      letterSpacing,
                    ),
                  ),

                  // Glitch tear bars across the screen.
                  if (glitching) ..._tearBars(t, constraints),

                  // Blackout / fade-from-black.
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: black),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTitle(
    double t,
    bool glitching,
    double opacity,
    double scale,
    double letterSpacing,
  ) {
    final baseStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Megatrans',
      fontSize: 92,
      letterSpacing: letterSpacing,
      height: 1.0,
      shadows: const [
        Shadow(color: Colors.cyanAccent, blurRadius: 18),
        Shadow(color: Colors.cyan, blurRadius: 42),
      ],
    );

    Widget content;
    if (!glitching) {
      content = Text(widget.controller.title, style: baseStyle);
    } else {
      // RGB-split + jitter glitch.
      final rng = Random((t * 1000).floor());
      final dx = (rng.nextDouble() - 0.5) * 14;
      final dy = (rng.nextDouble() - 0.5) * 6;
      content = Stack(
        children: [
          Transform.translate(
            offset: Offset(-6 + dx, dy),
            child: Text(
              widget.controller.title,
              style: baseStyle.copyWith(
                color: Colors.redAccent.withValues(alpha: 0.8),
                shadows: null,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(6 - dx, -dy),
            child: Text(
              widget.controller.title,
              style: baseStyle.copyWith(
                color: Colors.cyanAccent.withValues(alpha: 0.8),
                shadows: null,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx * 0.4, 0),
            child: Text(widget.controller.title, style: baseStyle),
          ),
        ],
      );
    }

    return Opacity(
      opacity: opacity,
      child: Transform.scale(scale: scale, child: content),
    );
  }

  List<Widget> _tearBars(double t, BoxConstraints constraints) {
    final rng = Random((t * 997).floor());
    final h = constraints.maxHeight;
    return [
      for (var i = 0; i < 3; i++)
        Positioned(
          top: h * (0.38 + rng.nextDouble() * 0.24),
          left: (rng.nextDouble() - 0.5) * 60,
          width: constraints.maxWidth,
          height: 2 + rng.nextDouble() * 12,
          child: IgnorePointer(
            child: ColoredBox(
              color: (i.isEven
                      ? Colors.cyanAccent
                      : const Color(0xFFFF3D8A))
                  .withValues(alpha: 0.22),
            ),
          ),
        ),
    ];
  }
}

/// Simple centered banner shown when a sector starts:
/// "DESTRUYE A TODOS LOS ENEMIGOS" — 0.3 s in, 2 s hold, 0.3 s out.
/// The level removes the overlay after ~2.6 s.
class LevelBannerOverlay extends StatefulWidget {
  const LevelBannerOverlay({super.key});

  @override
  State<LevelBannerOverlay> createState() => _LevelBannerOverlayState();
}

class _LevelBannerOverlayState extends State<LevelBannerOverlay>
    with SingleTickerProviderStateMixin {
  static const double _seconds = 2.6;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * _seconds;
        final fadeIn = (t / 0.3).clamp(0.0, 1.0);
        final fadeOut = ((t - 2.3) / 0.3).clamp(0.0, 1.0);
        final opacity = fadeIn * (1 - fadeOut);
        final scale = 0.92 + 0.08 * Curves.easeOutCubic.transform(fadeIn);

        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: const Text(
                  'DESTRUYE A TODOS LOS ENEMIGOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontFamily: 'Megatrans',
                    fontSize: 36,
                    letterSpacing: 6,
                    height: 1.1,
                    shadows: [
                      Shadow(color: Colors.cyan, blurRadius: 14),
                      Shadow(color: Colors.cyanAccent, blurRadius: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
