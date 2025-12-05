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
  double _currentZoom = 1.0;

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
        color: Colors.cyan.withAlpha(20),
        border: Border.all(color: Colors.cyan.withAlpha(50), width: 1),
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
            const SizedBox(height: 7),

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
      children: [
        Icon(Icons.bug_report, color: Colors.cyan, size: 15),
        SizedBox(width: 4),
        Text(
          '           DEBUG MENU',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            fontFamily: 'Megatrans',
            letterSpacing: 4.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFastModeToggle() {
    return Container(
      decoration: BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),

            child: Text(
              "velocidad:",
              style: TextStyle(color: Colors.cyan, fontSize: 12),
            ),
          ),
          const SizedBox(width: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpeedOption(80, "Normal"),
              const SizedBox(width: 30),
              _buildSpeedOption(250, "Rápido"),
            ],
          ),

          const SizedBox(height: 8),

          // Velocidad actual
        ],
      ),
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
                width: isSelected ? 1 : 0.5,
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
        color: const Color.fromARGB(39, 33, 33, 33),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 0.5),
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del zoom
          Row(
            children: [
              const Icon(Icons.zoom_in, color: Colors.blue, size: 10),
              const SizedBox(width: 8),
              const Text(
                'ZOOM LEVEL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'Megatrans',
                ),
              ),
              const Spacer(),
              Text(
                '${_currentZoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controles de zoom
          Row(
            children: [
              // Botón -
              Expanded(
                child: ElevatedButton.icon(
                  //icon: const Icon(Icons.remove, size: 10),
                  label: const Text('-', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 0.1).clamp(0.5, 3.0);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón +
              Expanded(
                child: ElevatedButton.icon(
                  //icon: const Icon(Icons.add, size: 10),
                  label: const Text('+', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 0.1).clamp(0.5, 3.0);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withAlpha(50),
                    foregroundColor: Colors.white,
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
    // Aquí implementarás la lógica del zoom en tu cámara
    // Por ejemplo:
    // widget.game.camera.zoom = _currentZoom;
    print('Zoom cambiado a: ${_currentZoom}x');
  }
}
