import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/game.dart';

class MainMenuButtons extends ConsumerStatefulWidget {
  const MainMenuButtons({required this.game, super.key});

  final MyGame game;

  @override
  ConsumerState<MainMenuButtons> createState() => _MainMenuButtonsState();
}

class _MenuAction {
  const _MenuAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _MainMenuButtonsState extends ConsumerState<MainMenuButtons> {
  static const double _width = 560;
  static const double _height = 360;
  static const int _visibleCount = 5;
  static const int _loopOffset = 1000;
  static const double _itemExtent = _height / _visibleCount;

  late final ScrollController _controller;

  MyGame get game => widget.game;

  List<_MenuAction> get _actions => [
        _MenuAction(label: 'Jugar', onPressed: _play),
        _MenuAction(
          label: 'Ranking',
          onPressed: () => game.overlays.add('Leaderboard'),
        ),
        _MenuAction(
          label: 'Crear Usuario',
          onPressed: () => game.overlays.add('CreateAccount'),
        ),
        _MenuAction(
          label: 'Configuracion',
          onPressed: () => Flame.device.setLandscapeRightOnly(),
        ),
        _MenuAction(label: 'Salir', onPressed: _exitApp),
        _MenuAction(
          label: 'creditos',
          onPressed: () => Flame.device.setLandscapeLeftOnly(),
        ),
        _MenuAction(label: 'Cerrar sesion', onPressed: _signOut),
      ];

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: _loopOffset * _actions.length * _itemExtent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final pilot = await ref.read(pilotRepositoryProvider).current();
    if (pilot == null) {
      game.overlays.add('CreateAccount');
      return;
    }
    game.overlays.remove('MainMenu');
    game.overlays.add('HudDecoration');
    game.overlays.add('ScoreBoard');
    game.resumeEngine();
    game.resumeBgmMusic();
  }

  Future<void> _signOut() async {
    await ref.read(pilotRepositoryProvider).signOut();
    ref.invalidate(currentPilotProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cerrada')),
    );
  }

  void _exitApp() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierra la pestaña para salir')),
      );
      return;
    }
    SystemNavigator.pop();
  }

  double _centerIndex() {
    if (!_controller.hasClients) {
      return (_loopOffset * _actions.length).toDouble();
    }
    return _controller.offset / _itemExtent;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final loopCount = actions.length * _loopOffset * 2;
    final endPad = (_height - _itemExtent) / 2;

    return SizedBox(
      width: _width,
      height: _height,
      child: ScrollConfiguration(
        behavior: _HudScrollBehavior(),
        child: ListView.builder(
          controller: _controller,
          itemExtent: _itemExtent,
          padding: EdgeInsets.symmetric(vertical: endPad),
          physics: const _HudSnapPhysics(itemExtent: _itemExtent),
          itemCount: loopCount,
          itemBuilder: (context, index) {
            final action = actions[index % actions.length];
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final distance = (index - _centerIndex()).abs();
                // Five slots stay visible: center=1, neighbors~0.6, outer pair~0.2
                final fade = (1.0 - distance * 0.4).clamp(0.0, 1.0);
                final selected = distance < 0.5;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: action.onPressed,
                  child: Opacity(
                    opacity: fade,
                    child: _MenuCarouselLabel(
                      label: action.label,
                      selected: selected,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MenuCarouselLabel extends StatelessWidget {
  const _MenuCarouselLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  static const List<Shadow> _whiteGlow = [
    Shadow(color: Colors.white, blurRadius: 8),
    Shadow(color: Colors.white, blurRadius: 16),
    Shadow(color: Colors.white70, blurRadius: 28),
    Shadow(color: Colors.white54, blurRadius: 40),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Megatrans',
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 5,
              color: selected ? Colors.cyanAccent : Colors.white54,
              shadows: selected ? _whiteGlow : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// One-slot snap, overdamped spring, no ballistic coast.
class _HudSnapPhysics extends ScrollPhysics {
  const _HudSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 2200,
    damping: 280,
  );

  static const double _flingVelocity = 180;

  @override
  _HudSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _HudSnapPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  @override
  SpringDescription get spring => _spring;

  @override
  double get minFlingVelocity => _flingVelocity;

  @override
  double get maxFlingVelocity => 600;

  double _targetPixels(ScrollMetrics position, double velocity) {
    final page = position.pixels / itemExtent;
    final double targetPage;
    if (velocity.abs() < _flingVelocity) {
      targetPage = page.roundToDouble();
    } else if (velocity > 0) {
      targetPage = page.floor() + 1;
    } else {
      targetPage = page.ceil() - 1;
    }
    return (targetPage * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      _spring,
      position.pixels,
      target,
      0,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _HudScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
