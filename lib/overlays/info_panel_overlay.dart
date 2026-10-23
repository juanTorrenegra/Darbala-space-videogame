import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

class InfoPanelOverlay extends StatefulWidget {
  const InfoPanelOverlay({super.key, required this.game});
  final MyGame game;

  @override
  State<InfoPanelOverlay> createState() => _InfoPanelOverlayState();
}

class _InfoPanelOverlayState extends State<InfoPanelOverlay> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _open ? 20 : 0,
      top: 250,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _open ? _buildPanel() : _buildTab(),
        ),
      ),
    );
  }

  Widget _buildTab() {
    return GestureDetector(
      key: const ValueKey('info-tab'),
      onTap: _toggle,
      child: Container(
        width: 50,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.cyan.withAlpha(70),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: Colors.cyanAccent.withAlpha(160)),
        ),
        child: const Icon(Icons.skip_next, color: Colors.cyanAccent, size: 22),
      ),
    );
  }

  Widget _buildPanel() {
    return GestureDetector(
      key: const ValueKey('info-panel'),
      onTap: _toggle,
      child: Transform(
        transform: Matrix4.skewX(-0.14),
        alignment: Alignment.centerLeft,
        child: Container(
          width: 400,
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              const Color.fromARGB(19, 31, 168, 157),
              Colors.black.withAlpha(45),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromARGB(80, 31, 168, 157)),
          ),
          child: _InfoPanelBody(game: widget.game),
        ),
      ),
    );
  }
}

class _InfoPanelBody extends StatelessWidget {
  const _InfoPanelBody({required this.game});

  final MyGame game;

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
    return ValueListenableBuilder<DebugInfo>(
      valueListenable: game.debugInfo,
      builder: (context, info, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    );
  }

  Widget _row(String label, String value) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label, style: _labelStyle)),
          Expanded(child: Text(value, style: _valueStyle)),
        ],
      ),
    );
  }
}
