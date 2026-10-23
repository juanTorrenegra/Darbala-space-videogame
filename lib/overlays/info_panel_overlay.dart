import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

class InfoPanelOverlay extends StatefulWidget {
  const InfoPanelOverlay({super.key, required this.game});
  final MyGame game;

  @override
  State<InfoPanelOverlay> createState() => _InfoPanelOverlayState();
}

class _InfoPanelOverlayState extends State<InfoPanelOverlay> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 80,
      top: 260,
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 300),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.black.withOpacity(0.75),
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        closedBuilder: (context, openContainer) => GestureDetector(
          onTap: openContainer,
          child: Transform.translate(
            offset: const Offset(-24, 0),
            child: Container(
              width: 32,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.cyan.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.skip_next, color: Colors.cyanAccent),
            ),
          ),
        ),
        openBuilder: (context, closeContainer) => _InfoPanelBody(
          game: widget.game,
          onClose: closeContainer,
        ),
      ),
    );
  }
}

class _InfoPanelBody extends StatelessWidget {
  const _InfoPanelBody({required this.game, required this.onClose});

  final MyGame game;
  final VoidCallback onClose;

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xFFDD5050),
    fontSize: 18,
    fontFamily: 'Ava',
    height: 20 / 18,
  );

  static final TextStyle _valueStyle = TextStyle(
    color: Colors.cyan.withAlpha(200),
    fontSize: 18,
    fontFamily: 'Ava',
    height: 20 / 18,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(19, 31, 168, 157)),
      ),
      child: Transform(
        transform: Matrix4.skewX(-0.14),
        alignment: Alignment.centerLeft,
        child: ValueListenableBuilder<DebugInfo>(
          valueListenable: game.debugInfo,
          builder: (context, info, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      color: Colors.cyanAccent,
                      size: 22,
                    ),
                  ),
                ),
                _row('Vida Jugador', '${info.hp}/${info.maxHp}'),
                _row(
                  'Posición',
                  '${info.x.toStringAsFixed(1)}, ${info.y.toStringAsFixed(1)}',
                ),
                _row('Naves Destruidas', '${info.shipsDestroyed}'),
                _row('Time Scale', '${info.timeScale.toStringAsFixed(2)}x'),
                _row('Estado', info.paused ? 'PAUSADO' : 'ACTIVO'),
                _row('Velocidad', info.speed.toStringAsFixed(0)),
                _row('Zoom', '${info.zoom.toStringAsFixed(2)}x'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 170,
          child: Text(label, style: _labelStyle),
        ),
        Text(value, style: _valueStyle),
      ],
    );
  }
}
