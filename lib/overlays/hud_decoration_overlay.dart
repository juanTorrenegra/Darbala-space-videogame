// hud_decoration_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/game.dart';

class HudDecorationOverlay extends ConsumerWidget {
  const HudDecorationOverlay({required this.game, super.key});
  final MyGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // IgnorePointer: este widget no bloquee los botones del hud.
    // SizedBox.expand so the painter uses the game frame size (1280×720),
    // not MediaQuery (browser size) — that mismatch pulled the right corners left.
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            CustomPaint(
              painter: const _HudDecorationPainter(),
              child: const SizedBox.expand(),
            ),
            const Positioned(
              top: 10,
              left: 36,
              child: _InGamePilotName(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InGamePilotName extends ConsumerWidget {
  const _InGamePilotName();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentPilotProvider);
    return session.when(
      data: (pilot) {
        if (pilot == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pilot.callSign,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontFamily: 'Megatrans',
                fontSize: 16,
                letterSpacing: 3,
                height: 1.1,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 8),
                  Shadow(color: Colors.white54, blurRadius: 16),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.military_tech, color: Colors.cyan, size: 18),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HudDecorationPainter extends CustomPainter {
  const _HudDecorationPainter();

  static const double _cornerInset = 25;
  static const double _notchInset = 35;
  static const double _edgeY = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 164, 164)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final glowPaint = Paint()
      ..color = const Color.fromARGB(250, 231, 42, 20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final armEndX = size.width / 3;
    final path = Path();

    // Top-left
    path
      ..moveTo(_cornerInset, _cornerInset)
      ..lineTo(_notchInset, _edgeY)
      ..lineTo(armEndX, _edgeY);

    // Top-right (mirror of top-left)
    path
      ..moveTo(size.width - _cornerInset, _cornerInset)
      ..lineTo(size.width - _notchInset, _edgeY)
      ..lineTo(size.width - armEndX, _edgeY);

    // Bottom-left
    path
      ..moveTo(_cornerInset, size.height - _cornerInset)
      ..lineTo(_notchInset, size.height - _edgeY)
      ..lineTo(armEndX, size.height - _edgeY);

    // Bottom-right (mirror of bottom-left)
    path
      ..moveTo(size.width - _cornerInset, size.height - _cornerInset)
      ..lineTo(size.width - _notchInset, size.height - _edgeY)
      ..lineTo(size.width - armEndX, size.height - _edgeY);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HudDecorationPainter oldDelegate) => false;
}
