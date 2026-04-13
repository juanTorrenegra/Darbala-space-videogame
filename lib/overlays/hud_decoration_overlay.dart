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
      ..color = Color.fromARGB(255, 255, 164, 164)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final glowPaint =
        Paint() // GLOW (la sombra borrosa cyan)
          ..color = Color.fromARGB(250, 231, 42, 20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final path = Path();

    //linea superior izquierda;

    path.moveTo(25, 25);
    path.lineTo(35, 15);
    path.lineTo(size.width / 3, 15);

    //intento de tab Forma L nariz  7.2
    //path.moveTo(0, size.height / 15);
    //path.lineTo(size.width / 10, size.height / 15);
    //path.lineTo(size.width / 8.5, size.height / 8);
    //path.lineTo(size.width / 6, size.height / 8);
    //path.lineTo(size.width / 5.5, size.height / 6);
    //path.lineTo(size.width / 5.5, size.height / 4.5);
    //path.lineTo(size.width / 8, size.height / 3.2);
    //path.lineTo(0, size.height / 3.2);

    //path.moveTo(40, 10);
    //path.lineTo(100, 10);
    //path.lineTo(110, 30);
    //path.lineTo(size.width / 5, 30);
    //path.lineTo(size.width / 5, 60);
    //
    //path.moveTo(size.width / 5 + 10, 30);
    //path.lineTo(size.width / 5 + 10, 60);
    //
    //path.moveTo(size.width / 5 + 20, 30);
    //path.lineTo(size.width / 5 + 20, size.height / 8);
    //path.lineTo(100, 10);

    // Esquina superior derecha
    path.moveTo(size.width - 25, 25);
    path.lineTo(size.width - 35, 15);
    path.lineTo(size.width - size.width / 3, 15);

    // Esquina inferior izquierda
    path.moveTo(20, size.height - 20);
    path.lineTo(60, size.height - 20);
    path.moveTo(20, size.height - 20);
    path.lineTo(20, size.height - 60);

    // Esquina inferior derecha
    path.moveTo(size.width - 5, size.height - 20);
    path.lineTo(size.width - 60, size.height - 20);
    path.moveTo(size.width - 20, size.height - 20);
    path.lineTo(size.width - 20, size.height - 60);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
