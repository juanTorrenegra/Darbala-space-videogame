import 'package:flutter/material.dart';

import 'package:juanshooter/game.dart';
import 'package:juanshooter/overlays/game_over.dart';

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
      width: MediaQuery.of(context).size.width * 0.28, // 1/4 de la pantalla
      height: MediaQuery.of(context).size.height * 0.7,
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
            const SizedBox(height: 16),

            // Fast Mode Toggle
            _buildFastModeToggle(),
            const SizedBox(height: 10),

            // Zoom Controls
            _buildZoomControls(),
            const SizedBox(height: 10),
            _buildTimeControls(),
            const SizedBox(height: 10),
            _buildResetControls(),
            const SizedBox(height: 10),
            _buildGameInfo(),
            const SizedBox(height: 10),
            // Espacio para futuros botones
            _buildPlaceholderButton('God Mode'),
            const SizedBox(height: 10),
            _buildPlaceholderButton('Spawn Enemy'),
            const SizedBox(height: 10),
            _buildPlaceholderButton('Reset Level'),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.game.cameraZoom;
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
            //fontWeight: FontWeight.bold,
            fontFamily: 'Megatrans',
            letterSpacing: 2,
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
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 0.1,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Zoom',
                style: TextStyle(
                  color: Colors.cyan,
                  //fontWeight: FontWeight.bold,
                  fontSize: 12,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 0.01).clamp(0.5, 3);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(30),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 20),
                  ),
                  child: const Text('-1', style: TextStyle(fontSize: 10)),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('+1', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 0.01).clamp(0.5, 3);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withAlpha(30),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('-5', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 0.05).clamp(0.5, 3);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(30),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 20),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton.icon(
                  label: const Text('+5', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 0.05).clamp(0.5, 3);
                      _applyZoom();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withAlpha(30),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 20),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPresetZoomButton(0.5, '0.5x'),
              _buildPresetZoomButton(1.0, '1x'),
              _buildPresetZoomButton(2.0, '2x'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetZoomButton(double zoom, String label) {
    return TextButton(
      onPressed: () {
        setState(() {
          _currentZoom = zoom;
          _applyZoom();
        });
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 20),
        backgroundColor: _currentZoom == zoom
            ? Colors.cyan.withAlpha(50)
            : Colors.transparent,
      ),
      child: Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: _currentZoom == zoom ? Colors.cyan : Colors.grey,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.slow_motion_video,
                size: 14,
                color: Colors.cyanAccent,
              ),
              const SizedBox(width: 6),
              const Text(
                'TIEMPO',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontFamily: 'Megatrans',
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.game.timeScale.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Megatrans',
                ),
              ),
            ],
          ),
        ),

        // Controles finos (±0.1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.game.setTimeScale(widget.game.timeScale - 0.1);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withAlpha(20),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('-0.1', style: TextStyle(fontSize: 10)),
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.game.setTimeScale(widget.game.timeScale + 0.1);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withAlpha(20),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('+0.1', style: TextStyle(fontSize: 10)),
                ),
              ),

              const SizedBox(width: 12),

              // Controles más grandes (±0.5)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.game.setTimeScale(widget.game.timeScale - 0.5);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.withAlpha(30),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('-0.5', style: TextStyle(fontSize: 10)),
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.game.setTimeScale(widget.game.timeScale + 0.5);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.withAlpha(30),
                    foregroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('+0.5', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Botones de valores predefinidos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildTimePresetButton(0.1, '0.1x\n-- lento'),
              _buildTimePresetButton(0.25, '0.25x\n- lento'),
              _buildTimePresetButton(0.5, '0.5x\nLento'),
              _buildTimePresetButton(1.0, '1x\nNormal'),
              _buildTimePresetButton(2.0, '2x\nRápido'),
              _buildTimePresetButton(3.0, '3x\n+ rápido'),
              _buildTimePresetButton(5.0, '5x\n++ rápido'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimePresetButton(double scale, String label) {
    bool isSelected =
        (widget.game.timeScale - scale).abs() < 0.05; // Tolerancia de ±0.05

    return GestureDetector(
      onTap: () {
        widget.game.setTimeScale(scale);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withAlpha(80)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : Colors.cyanAccent.withAlpha(30),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.split('\n')[0],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.cyanAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (label.contains('\n')) ...[
              Text(
                label.split('\n')[1],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.cyanAccent.withAlpha(150),
                  fontSize: 7,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResetControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.restart_alt, size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              const Text(
                'CONTROLES DE RESET',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontFamily: 'Megatrans',
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Botones individuales
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildResetButton('⏸️ Pausa', () {
              widget.game.togglePause();
              setState(() {});
            }, Colors.blue),

            _buildResetButton('🎮 Toggle GameOver', () {
              _toggleGameOverComponent();
            }, Colors.deepOrange),

            _buildResetButton('💥 Limpiar', () {
              widget.game.clearAllGameEntities();
            }, Colors.purple),

            _buildResetButton('👤 Reset Jugador', () {
              widget.game.resetPlayerState();
            }, Colors.green),

            _buildResetButton('📊 Reset Stats', () {
              widget.game.resetGameStats();
              setState(() {});
            }, Colors.cyan),

            _buildResetButton('🎥 Reset Cámara', () {
              widget.game.resetCamera();
              setState(() {
                _currentZoom = 0.5;
              });
            }, Colors.amber),
            _buildResetButton('💀 Matar Jugador', () {
              _killPlayerForTesting();
            }, Colors.red),

            _buildResetButton('🖥️ Reset HUD', () {
              widget.game.resetHUD();
            }, Colors.teal),
          ],
        ),

        // Botón de RESET COMPLETO (rojo)
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            _executeFullReset();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withAlpha(80),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 16),
              SizedBox(width: 8),
              Text(
                'RESET COMPLETO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton(String text, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(30),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withAlpha(100), width: 1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _executeFullReset() {
    // Ejecutar todos los métodos en secuencia
    print('🔄 INICIANDO RESET COMPLETO...');

    widget.game.removeGameOverComponent();
    widget.game.clearAllGameEntities();
    widget.game.resetPlayerState();
    widget.game.resetGameStats();
    widget.game.resetCamera();
    widget.game.resetHUD();

    // Si estaba pausado, reanudar
    if (widget.game.paused) {
      widget.game.resumeEngine();
    }

    print('✅ RESET COMPLETO FINALIZADO');

    // Cerrar el debug menu
    setState(() {
      _isDrawerOpen = false;
    });
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMACIÓN DEL JUEGO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildInfoRow(
            'Vida Jugador',
            '${widget.game.player.currentHitPoints}/${widget.game.player.maxHitPoints}',
          ),
          _buildInfoRow(
            'Posición',
            '${widget.game.player.position.x.toStringAsFixed(1)}, ${widget.game.player.position.y.toStringAsFixed(1)}',
          ),
          _buildInfoRow('Naves Destruidas', '${widget.game.shipsDestroyed}'),
          _buildInfoRow(
            'Time Scale',
            '${widget.game.timeScale.toStringAsFixed(2)}x',
          ),
          _buildInfoRow('Estado', widget.game.paused ? 'PAUSADO' : 'ACTIVO'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 9)),
          Text(
            value,
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 6),
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

  void _toggleGameOverComponent() {
    if (widget.game.camara?.viewport != null) {
      // Buscar si ya existe un GameOverComponent
      final existingComponents = widget.game.camara!.viewport.children
          .whereType<GameOverComponent>()
          .toList();

      if (existingComponents.isEmpty) {
        // No existe, crear uno nuevo CON referencia al juego
        final gameOver = GameOverComponent(game: widget.game);
        widget.game.camara!.viewport.add(gameOver);
        print('✅ GameOverComponent AÑADIDO manualmente');

        // Verificar después de un breve momento
        Future.delayed(Duration(milliseconds: 100), () {
          print('🔄 Verificando si se montó correctamente...');
          print(
            '📍 Componentes en viewport: ${widget.game.camara!.viewport.children.length}',
          );
          final gameOverCheck = widget.game.camara!.viewport.children
              .whereType<GameOverComponent>()
              .toList();
          print('🎮 GameOverComponents encontrados: ${gameOverCheck.length}');
          if (gameOverCheck.isNotEmpty) {
            print(
              '✅ GameOverComponent montado: ${gameOverCheck.first.isMounted}',
            );
            print('✅ Tamaño: ${gameOverCheck.first.size}');
          }
        });
      } else {
        // Ya existe, removerlo
        for (final component in existingComponents) {
          component.removeFromParent();
          print('✅ GameOverComponent REMOVIDO manualmente');
        }
      }
    } else {
      print('❌ No se puede añadir GameOverComponent: cámara no disponible');
    }
  }

  void _killPlayerForTesting() {
    widget.game.player.die();
  }
}
