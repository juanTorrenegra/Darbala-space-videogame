import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';

const _speedPresets = <double>[
  10,
  25,
  50,
  60,
  70,
  80,
  90,
  100,
  120,
  140,
  150,
  175,
  200,
  225,
  250,
  275,
  300,
  500,
  900,
];

const _zoomPresets = <double>[
  0.10,
  0.20,
  0.40,
  0.50,
  0.60,
  0.70,
  0.80,
  1.00,
  1.25,
  1.50,
  1.75,
  2.00,
  2.25,
  2.50,
  2.75,
  3.00,
  5.00,
];

const _timePresets = <double>[0.1, 0.5, 0.7, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0];

class DebugPanelTab extends StatefulWidget {
  const DebugPanelTab({super.key, required this.game, required this.info});

  final MyGame game;
  final DebugInfo info;

  @override
  State<DebugPanelTab> createState() => _DebugPanelTabState();
}

class _DebugPanelTabState extends State<DebugPanelTab> {
  void _apply(VoidCallback fn) {
    fn();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final info = widget.info;
    return Column(
      children: [
        Expanded(
          child: _DebugControlRow(
            title: 'speed',
            values: _speedPresets,
            current: info.speed,
            step: 5,
            min: 1,
            max: 900,
            format: (v) => v.round().toString(),
            near: 0.4,
            onChanged: (v) => _apply(() => game.setPlayerSpeed(v)),
          ),
        ),
        Expanded(
          child: _DebugControlRow(
            title: 'zoom',
            values: _zoomPresets,
            current: info.zoom,
            step: 0.01,
            min: 0.10,
            max: 3.00,
            format: (v) => v.toStringAsFixed(2),
            near: 0.004,
            onChanged: (v) => _apply(() => game.setCameraZoom(v)),
          ),
        ),
        Expanded(
          child: _DebugControlRow(
            title: 'time',
            values: _timePresets,
            current: info.timeScale,
            step: 0.1,
            min: 0.1,
            max: 5.0,
            format: (v) => v.toStringAsFixed(1),
            near: 0.04,
            onChanged: (v) => _apply(() => game.setTimeScale(v)),
          ),
        ),
        Expanded(
          child: _DebugActionCarousel(
            game: game,
            onChanged: () => setState(() {}),
          ),
        ),
      ],
    );
  }
}

class _DebugControlRow extends StatelessWidget {
  const _DebugControlRow({
    required this.title,
    required this.values,
    required this.current,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.near,
    required this.onChanged,
  });

  final String title;
  final List<double> values;
  final double current;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final double near;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Megatrans',
                      height: 1,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _NumberCarousel(
                  values: values,
                  current: current,
                  format: format,
                  near: near,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _StepHit(
                  label: '−',
                  onTap: () => onChanged((current - step).clamp(min, max)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: FittedBox(
                    child: Text(
                      format(current),
                      style: debugGlowStyle(true, 36),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _StepHit(
                  label: '+',
                  onTap: () => onChanged((current + step).clamp(min, max)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberCarousel extends StatelessWidget {
  const _NumberCarousel({
    required this.values,
    required this.current,
    required this.format,
    required this.near,
    required this.onChanged,
  });

  final List<double> values;
  final double current;
  final String Function(double) format;
  final double near;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 8),
      itemCount: values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = (value - current).abs() <= near;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: Center(
            child: Text(format(value), style: debugGlowStyle(selected, 22)),
          ),
        );
      },
    );
  }
}

class _DebugActionCarousel extends StatelessWidget {
  const _DebugActionCarousel({required this.game, required this.onChanged});

  final MyGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _ActionText(
          label: 'hostile',
          glowing: game.enemyHostilityEnabled,
          onTap: () {
            game.setEnemyHostilityEnabled(!game.enemyHostilityEnabled);
            onChanged();
          },
        ),
        const SizedBox(width: 14),
        _ActionText(
          label: 'markers',
          glowing: game.enemyMarkersEnabled,
          onTap: () {
            game.setEnemyMarkersEnabled(!game.enemyMarkersEnabled);
            onChanged();
          },
        ),
        const SizedBox(width: 14),
        _ActionText(
          label: 'kill-Enemy',
          glowing: false,
          onTap: game.destroyAllTargets,
        ),
        const SizedBox(width: 14),
        _ActionText(
          label: 'kill-player',
          glowing: false,
          onTap: () => game.player.die(),
        ),
      ],
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.label,
    required this.glowing,
    required this.onTap,
  });

  final String label;
  final bool glowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(child: Text(label, style: debugGlowStyle(glowing, 24))),
    );
  }
}

class _StepHit extends StatelessWidget {
  const _StepHit({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 32,
            fontFamily: 'Megatrans',
            height: 1,
          ),
        ),
      ),
    );
  }
}

TextStyle debugGlowStyle(bool glowing, double size) {
  return TextStyle(
    color: glowing ? Colors.cyanAccent : Colors.white70,
    fontSize: size,
    fontFamily: 'Megatrans',
    height: 1,
    shadows: glowing
        ? const [
            Shadow(color: Colors.cyanAccent, blurRadius: 8),
            Shadow(color: Colors.cyanAccent, blurRadius: 16),
          ]
        : null,
  );
}
