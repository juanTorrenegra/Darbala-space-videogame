import 'package:flutter/material.dart';

import 'package:juanshooter/game.dart';

class DebugMenu extends StatefulWidget {
  final MyGame game;

  const DebugMenu({required this.game, super.key});

  @override
  State<DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends State<DebugMenu> {
  bool _isDrawerOpen = false;
  double _currentZoom = 0.5;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 30,
      child: Row(
        children: [
          // Icono del menú (siempre visible)
          _buildMenuIcon(),

          // Drawer desplegable
          if (_isDrawerOpen) _buildDebugDrawer(),
        ],
      ),
    );
  }

  Widget _buildMenuIcon() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDrawerOpen = !_isDrawerOpen;
        });
      },
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withAlpha(50)),
        child: const Icon(Icons.bug_report, color: Colors.cyan, size: 18),
      ),
    );
  }

  Widget _buildDebugDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.29, // 1/4 de la pantalla
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withAlpha(22),
        //border: Border.all(color: Colors.cyan.withAlpha(50), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 12),

            // Fast Mode Toggle
            _buildFastModeToggle(),
            const SizedBox(height: 6),

            // Zoom Controls
            _buildZoomControls(),
            const SizedBox(height: 6),

            // Espacio para futuros botones
            _buildPlaceholderButton('God Mode'),
            const SizedBox(height: 8),
            _buildPlaceholderButton('Spawn Enemy'),
            const SizedBox(height: 8),
            _buildPlaceholderButton('Reset Level'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      //mainAxisAlignment: MainAxisAlignment.start,
      children: [
        //Icon(Icons.bug_report, color: Colors.cyan, size: 15),
        //SizedBox(width: 4),
        Text(
          'DEBUG MENU',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            fontFamily: 'Megatrans',
            letterSpacing: 4.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFastModeToggle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),

          child: Text(
            "Velocidad",
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 12,
              fontFamily: 'Megatrans',
              letterSpacing: 2,
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpeedOption(80, "Normal"),
            const SizedBox(width: 30),
            _buildSpeedOption(250, "Rápido"),
          ],
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpeedOption(int speed, String label) {
    bool isSelected = widget.game.player.currentSpeed == speed;

    return GestureDetector(
      onTap: () {
        setState(() {
          widget.game.player.isFastMode = (speed == 250);
          widget.game.player.currentSpeed = speed.toDouble();
        });
      },
      child: Column(
        children: [
          // Número de velocidad
          Container(
            width: 30,
            height: 20,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.cyan.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.cyan : Colors.grey,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                '$speed',
                style: TextStyle(
                  color: isSelected ? Colors.cyan : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Etiqueta
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.cyan : Colors.grey,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        //borderRadius: BorderRadius.circular(8),
        //border: Border.all(color: Colors.blue, width: 0.5),
      ),
      //padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'ZOOM LEVEL',
                style: TextStyle(
                  color: Colors.cyan,
                  //fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'Megatrans',
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                '${_currentZoom.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Megatrans',
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Controles de zoom
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('-1', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 0.01).clamp(0.5, 3.5);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(50),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton.icon(
                  //icon: const Icon(Icons.add, size: 10),
                  label: const Text('+1', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 0.01).clamp(0.5, 3.5);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withAlpha(50),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('-5', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 0.05).clamp(0.5, 3.5);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(50),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton.icon(
                  //icon: const Icon(Icons.add, size: 10),
                  label: const Text('+5', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 0.05).clamp(0.5, 3.5);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withAlpha(50),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),

          // Slider de zoom (opcional)
        ],
      ),
    );
  }

  Widget _buildPlaceholderButton(String text) {
    return ElevatedButton(
      onPressed: () {
        // Placeholder para futuras funcionalidades
        print('$text pressed');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(38, 24, 255, 255),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Megatrans',
        ),
      ),
    );
  }

  void _applyZoom() {
    widget.game.setCameraZoom(_currentZoom);
    print('Zoom cambiado a: ${_currentZoom}x');
  }
}
// Aquí implementarás la lógica del zoom en tu cámara
    // Por ejemplo:
    // widget.game.camera.zoom = _currentZoom;