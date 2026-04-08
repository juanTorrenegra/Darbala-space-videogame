// hud_decoration_overlay.dart
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

class HudDecorationOverlay extends StatelessWidget {
  const HudDecorationOverlay({required this.game, super.key});
  final MyGame game;

  @override
  Widget build(BuildContext context) {
    // IgnorePointer:este widget no bloquee los botones del hud
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Este CustomPaint se dibujará encima del juego pero detrás de otros overlays
            CustomPaint(
              painter: _HudDecorationPainter(),
              size: MediaQuery.of(context).size,
            ),
          ],
        ),
      ),
    );
  }
}

class _HudDecorationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final path = Path();

    // Esquina superior izquierda
    path.moveTo(20, 20);
    path.lineTo(60, 20);
    path.moveTo(20, 20);
    path.lineTo(20, 60);

    // Esquina superior derecha
    path.moveTo(size.width - 20, 20);
    path.lineTo(size.width - 60, 20);
    path.moveTo(size.width - 20, 20);
    path.lineTo(size.width - 20, 60);

    // Esquina inferior izquierda
    path.moveTo(20, size.height - 20);
    path.lineTo(60, size.height - 20);
    path.moveTo(20, size.height - 20);
    path.lineTo(20, size.height - 60);

    // Esquina inferior derecha
    path.moveTo(size.width - 20, size.height - 20);
    path.lineTo(size.width - 60, size.height - 20);
    path.moveTo(size.width - 20, size.height - 20);
    path.lineTo(size.width - 20, size.height - 60);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
