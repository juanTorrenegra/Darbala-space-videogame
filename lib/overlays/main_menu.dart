import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/overlays/main_menu_buttons.dart';

class VisorOverlay extends ConsumerStatefulWidget {
  const VisorOverlay({required this.game, super.key});

  final MyGame game;

  @override
  ConsumerState<VisorOverlay> createState() => _VisorOverlayState();
}

class _VisorOverlayState extends ConsumerState<VisorOverlay> {
  MyGame get game => widget.game;

  /// Gap to the right of the elevated buttons. Raise to push modes farther right.
  static const double stickModeOffsetX = 55;

  /// Down from the top of Jugar. Raise to drop the stack, lower to raise it.
  static const double stickModeOffsetY = 20;

  /// Font size for the 1/2 joystick mode labels.
  static const double stickModeFontSize = 25;

  @override
  void dispose() {
    // Si el menú se cierra/remueve, reanudar música de fondo.
    game.resumeBgmMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // Fondo completamente transparente
      child: _MenuBootFx(
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

            Positioned(top: 505, left: 80, child: _ArtilleroNamePlate()),

            // 3) -- Los botones y otros widgets de interfaz encima del visor --
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  ClipRect(
                    child: Text(
                      'DARBALA',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Megatrans',
                        fontWeight: FontWeight.w400,
                        fontSize: 150,
                        letterSpacing: 60,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 80),
                    child: ref
                        .watch(gameFlagsProvider)
                        .when(
                          data: (flags) => Text(
                            flags.transmissionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: flags.fromRemote
                                  ? Colors.cyanAccent.withValues(alpha: 0.75)
                                  : Colors.orangeAccent.withValues(alpha: 0.85),
                              fontFamily: 'Megatrans',
                              fontSize: 14,
                              letterSpacing: 3,
                            ),
                          ),
                          loading: () => const SizedBox(height: 18),
                          error: (_, __) => const SizedBox(height: 18),
                        ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: stickModeOffsetX,
                              top: stickModeOffsetY,
                            ),
                            child: kIsWeb
                                ? _cellularModeOption()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _stickModeOption(
                                        '1 joystick mode',
                                        AppStickMode.single,
                                      ),
                                      const SizedBox(height: 18),
                                      _stickModeOption(
                                        '2 joystick mode',
                                        AppStickMode.dual,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      MainMenuButtons(game: game),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stickModeOption(String label, AppStickMode mode) {
    final selected = game.stickMode == mode;
    return GestureDetector(
      onTap: () {
        game.setStickMode(mode);
        setState(() {});
      },
      child: _modeLabel(label, selected),
    );
  }

  Widget _cellularModeOption() {
    final selected = game.cellularMode;
    return GestureDetector(
      onTap: () {
        game.setCellularMode(!game.cellularMode);
        setState(() {});
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _modeLabel('modo celular', selected),
      ),
    );
  }

  Widget _modeLabel(String label, bool selected) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Megatrans',
        fontSize: stickModeFontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 3,
        color: selected ? Colors.cyan : Colors.white38,
        shadows: selected
            ? const [
                Shadow(color: Colors.white, blurRadius: 8),
                Shadow(color: Colors.white, blurRadius: 16),
                Shadow(color: Colors.white70, blurRadius: 28),
              ]
            : null,
      ),
    );
  }
}

class _ArtilleroNamePlate extends ConsumerWidget {
  static const double _skewX = 0.20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentPilotProvider);
    return session.when(
      data: (pilot) {
        if (pilot == null) return const SizedBox.shrink();
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.skewX(_skewX),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 22, 10),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.08),
              border: Border.all(color: Colors.cyan, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ARTILLERO',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontFamily: 'Megatrans',
                        fontSize: 13,
                        letterSpacing: 4,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.military_tech, color: Colors.cyan, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pilot.callSign,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontFamily: 'Megatrans',
                    fontSize: 22,
                    letterSpacing: 3,
                    height: 1.1,
                    shadows: [
                      Shadow(color: Colors.white, blurRadius: 8),
                      Shadow(color: Colors.white54, blurRadius: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// One-second boot: 0–0.5s interference jitter, 0.5–1s veil lift.
/// No extra blur, no screenshot copies — only a translate + a few rects.
class _MenuBootFx extends StatefulWidget {
  const _MenuBootFx({required this.child});

  final Widget child;

  @override
  State<_MenuBootFx> createState() => _MenuBootFxState();
}

class _MenuBootFxState extends State<_MenuBootFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _boot;

  @override
  void initState() {
    super.initState();
    _boot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _boot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _boot,
      child: widget.child,
      builder: (context, child) {
        if (_boot.isCompleted) return child!;

        final t = _boot.value;
        final interference = t < 0.5;
        final step = (t * 22).floor();
        final rng = Random(step);

        var jitter = Offset.zero;
        if (interference) {
          final amp = 11.0 * (1.0 - t / 0.5);
          jitter = Offset(
            (rng.nextDouble() - 0.5) * 2 * amp,
            (rng.nextDouble() - 0.5) * amp * 0.45,
          );
        }

        final veil = interference
            ? (rng.nextBool() ? 0.08 : 0.28)
            : 0.55 * (1.0 - (t - 0.5) / 0.5);

        return LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            return Stack(
              children: [
                Transform.translate(offset: jitter, child: child),
                if (interference) ..._tearBars(rng, w, h),
                if (veil > 0.02)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: veil),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _tearBars(Random rng, double w, double h) {
    return [
      for (var i = 0; i < 2; i++)
        Positioned(
          top: h * (0.12 + rng.nextDouble() * 0.7),
          left: (rng.nextDouble() - 0.5) * 48,
          width: w,
          height: 3 + rng.nextDouble() * 16,
          child: IgnorePointer(
            child: ColoredBox(
              color: (i.isEven ? Colors.cyanAccent : const Color(0xFFFF3D8A))
                  .withValues(alpha: 0.22),
            ),
          ),
        ),
    ];
  }
}

// --------------------------------------------------------a
// LA CLASE QUE DIBUJA EL VISOR
// --------------------------------------------------------a
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
    lowerearLeft.moveTo(30, size.height - 190);
    lowerearLeft.lineTo(30, size.height - 150);
    lowerearLeft.lineTo(10, size.height - 125);
    lowerearLeft.lineTo(10, size.height - 65);
    lowerearLeft.lineTo(45, size.height - 15);
    lowerearLeft.lineTo(180, size.height - 15);
    lowerearLeft.lineTo(280, size.height - 110);
    //canvas.drawPath(lowerearLeft, helmetGlowPaint);
    canvas.drawPath(lowerearLeft, helmetPaint);

    Path lowerearRight = Path();
    lowerearRight.moveTo(size.width - 30, size.height - 190);
    lowerearRight.lineTo(size.width - 30, size.height - 150);
    lowerearRight.lineTo(size.width - 10, size.height - 125);
    lowerearRight.lineTo(size.width - 10, size.height - 65);
    lowerearRight.lineTo(size.width - 45, size.height - 15);
    lowerearRight.lineTo(size.width - 180, size.height - 15);
    lowerearRight.lineTo(size.width - 280, size.height - 110);
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
