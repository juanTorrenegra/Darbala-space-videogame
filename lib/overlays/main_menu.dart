import 'dart:math';
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

import 'package:flutter/material.dart';

class VisorOverlay extends StatelessWidget {
  const VisorOverlay({required this.game, super.key});

  final MyGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // Fondo completamente transparente
      child: Stack(
        children: [
          //Positioned.fill(
          //  child: Container(
          //    color: const Color(0xAA000000), //Fondo negro semi-transparente
          //  ),
          //),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 5.0,
                  sigmaY: 5.0, // Intensidad del blur
                ),
                child: Container(
                  color: Colors
                      .transparent, // Contenedor vacío, solo importa el filtro
                ),
              ),
            ),
          ),

          // 2) -- Nuestro visor espacial dibujado encima --
          CustomPaint(painter: MenuPainter(), size: Size.infinite),

          // 3) -- Los botones y otros widgets de interfaz encima del visor --
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DARBALA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: "ava",
                    fontWeight: FontWeight.w400,
                    fontSize: 90,
                    letterSpacing: 60,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    game.overlays.remove('MainMenu');
                    game.overlays.add("HudDecoration");
                    game.overlays.add("ScoreBoard");
                    //game.setTimeScale(1.0);
                    game.resumeEngine();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: .2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 80,
                      vertical: 7,
                    ),
                    elevation: 8,
                    shadowColor: Colors.black,
                  ),
                  child: const Text(
                    'Jugar',
                    style: TextStyle(
                      fontFamily: "Megatrans",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Flame.device.setLandscapeRightOnly();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: .2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 7,
                    ),

                    elevation: 8,
                    shadowColor: Colors.black,
                  ),

                  child: const Text(
                    'Configuracion',
                    style: TextStyle(
                      fontFamily: "Megatrans",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Flame.device.setLandscapeLeftOnly();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: .2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 7,
                    ),

                    elevation: 8,
                    shadowColor: Colors.black,
                  ),
                  child: const Text(
                    'Creditos',
                    style: TextStyle(
                      fontFamily: "Megatrans",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// LA CLASE QUE DIBUJA EL VISOR
// --------------------------------------------------------
class MenuPainter extends CustomPainter {
  //colors
  //Color.fromARGB(255, 255, 164, 164) inner red
  //Color.fromARGB(250, 231, 42, 20) glow red

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.19; // Radio del visor principal
    final maxRadiusB2 = size.width * 0.32;

    // -- 2. Borde del visor: Gradiente circular cyan que se difumina --
    //final gradient = SweepGradient(
    //  colors: [Colors.cyan, Colors.transparent],
    //  stops: [0.7, 1.0],
    //);
    //final shader = gradient.createShader(
    //  Rect.fromCircle(center: center, radius: maxRadius),
    //); efecto loading, gradiente circular- shader below

    final borderPaint = Paint()
      //..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 21.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    canvas.drawCircle(center, maxRadius, borderPaint);

    // -- 3. Cruz de mira en el centro (simulando un telescopio) --
    final crosshairPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final crosshairPaintAlpha = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final glowPaint =
        Paint() // GLOW (la sombra borrosa cyan)
          ..color = Colors.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    // Líneas horizontales y verticales
    double crosshairSize = 30.0;
    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      crosshairPaint,
    );

    // Círculo de la mira
    canvas.drawCircle(center, crosshairSize / 2, crosshairPaint);

    canvas.drawCircle(center, 320 / 2, glowPaint);
    canvas.drawCircle(center, 320 / 2, crosshairPaint);
    canvas.drawCircle(center, 310 / 2, crosshairPaint);

    // -- 4. "Medidores" o marcadores alrededor del borde --
    // Por ejemplo, marcas de grado cada 30 grados
    for (double angle = 0; angle < 360; angle += 15) {
      double radians = angle * (3.14159 / 180.0);
      // Calcula el punto en el borde del círculo
      Offset start = Offset(
        center.dx + maxRadius * cos(radians),
        center.dy + maxRadius * sin(radians),
      );
      // Calcula un punto un poco hacia adentro para la marca
      Offset end = Offset(
        center.dx + (maxRadius - 11) * cos(radians),
        center.dy + (maxRadius - 11) * sin(radians),
      );
      canvas.drawLine(start, end, crosshairPaint);
    }
    // halo compuesto de lineas radiales (crosshair)
    for (double angle = 0; angle < 360; angle += 1) {
      double radians = angle * (3.14159 / 180.0);
      // Calcula el punto en el borde del círculo
      Offset start = Offset(
        center.dx + maxRadiusB2 * cos(radians),
        center.dy + maxRadiusB2 * sin(radians),
      );
      // Calcula un punto un poco hacia adentro para la marca
      Offset end = Offset(
        center.dx + (maxRadiusB2 - 10) * cos(radians),
        center.dy + (maxRadiusB2 - 10) * sin(radians),
      );
      canvas.drawLine(start, end, crosshairPaintAlpha);
    }
    final helmetPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;
    final helmetGlowPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..strokeCap = StrokeCap.round;

    // Espejamos los puntos en el eje X restando de 'size.width'
    Path helmetPathRight = Path(); //oreja derecha
    helmetPathRight.moveTo(size.width - 260, 110);
    helmetPathRight.lineTo(size.width - 150, 20);
    helmetPathRight.lineTo(size.width - 35, 20);
    helmetPathRight.lineTo(size.width - 10, 50);
    helmetPathRight.lineTo(size.width - 10, 125);
    helmetPathRight.lineTo(size.width - 75, 180);
    //canvas.drawPath(helmetPathRight, helmetGlowPaint);
    canvas.drawPath(helmetPathRight, helmetPaint);

    Path helmetPath = Path();
    helmetPath.moveTo(260, 110); // Posicionar el "lápiz" en el start
    helmetPath.lineTo(150, 20); //línea hasta el primer pico
    helmetPath.lineTo(35, 20); // Bajar al primer valle
    helmetPath.lineTo(10, 50); // Subir al segundo pico
    helmetPath.lineTo(10, 125); // Bajar al punto final
    helmetPath.lineTo(75, 180);
    //canvas.drawPath(helmetPath, helmetGlowPaint);
    canvas.drawPath(helmetPath, helmetPaint);

    Path earlineRight = Path();
    earlineRight.moveTo(290, 80);
    earlineRight.lineTo(270, 60);
    earlineRight.lineTo(50, 60);
    earlineRight.lineTo(0, 10);
    //canvas.drawPath(earlineRight, helmetGlowPaint);
    canvas.drawPath(earlineRight, helmetPaint);

    Path earlineLeft = Path();
    earlineLeft.moveTo(size.width - 290, 80);
    earlineLeft.lineTo(size.width - 270, 60);
    earlineLeft.lineTo(size.width - 50, 60);
    earlineLeft.lineTo(size.width - 0, 10);
    //canvas.drawPath(earlineRight, helmetGlowPaint);
    canvas.drawPath(earlineLeft, helmetPaint);

    Path lowerearLeft = Path();
    lowerearLeft.moveTo(30, 210);
    lowerearLeft.lineTo(30, 260);
    lowerearLeft.lineTo(10, 285);
    lowerearLeft.lineTo(10, 340);
    lowerearLeft.lineTo(45, 380);
    lowerearLeft.lineTo(180, 380);
    lowerearLeft.lineTo(280, 300);
    //canvas.drawPath(lowerearLeft, helmetGlowPaint);
    canvas.drawPath(lowerearLeft, helmetPaint);

    Path lowerearRight = Path();
    lowerearRight.moveTo(size.width - 30, 210);
    lowerearRight.lineTo(size.width - 30, 260);
    lowerearRight.lineTo(size.width - 10, 285);
    lowerearRight.lineTo(size.width - 10, 340);
    lowerearRight.lineTo(size.width - 45, 380);
    lowerearRight.lineTo(size.width - 180, 380);
    lowerearRight.lineTo(size.width - 280, 300);
    //canvas.drawPath(lowerearRight, helmetGlowPaint);
    canvas.drawPath(lowerearRight, helmetPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Si quieres animar propiedades, aquí debes comparar el oldDelegate con this
    // y return true si cambiaron. Para un diseño estático, return false es eficiente.
    return false;
  }
}
