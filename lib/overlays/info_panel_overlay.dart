import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/overlays/debug_panel_tab.dart';
import 'package:juanshooter/overlays/levels_panel_tab.dart';
import 'package:juanshooter/overlays/sprites_panel_tab.dart';

const Color _tabColor = Color(0x4640E0D0);

final Color _panelColor = Color.alphaBlend(
  const Color.fromARGB(70, 31, 168, 157),
  Colors.black.withAlpha(45),
);

enum _PanelTab { debug, sprites, level, info }

class InfoPanelOverlay extends StatelessWidget {
  const InfoPanelOverlay({super.key, required this.game});
  final MyGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _HitTestChildrenOnly(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 20,
              top: 150,
              width: 540,
              height: 400,
              child: Transform(
                transform: Matrix4.skewX(-0.14),
                alignment: Alignment.centerLeft,
                child: Navigator(
                  onGenerateRoute: (settings) {
                    return PageRouteBuilder<void>(
                      settings: settings,
                      opaque: false,
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return _TopLeftPassThrough(
                          child: OpenContainer<void>(
                            useRootNavigator: false,
                            transitionType: ContainerTransitionType.fadeThrough,
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            closedElevation: 0,
                            openElevation: 0,
                            closedColor: _tabColor,
                            openColor: _panelColor,
                            middleColor: _panelColor,
                            closedShape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            openShape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            closedBuilder: (context, action) {
                              return const SizedBox(
                                width: 50,
                                height: 56,
                                child: Center(
                                  child: Icon(
                                    Icons.apps,
                                    color: Colors.cyanAccent,
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                            openBuilder: (context, action) {
                              return SizedBox.expand(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    10,
                                  ),
                                  child: _OpenPanel(game: game, close: action),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenPanel extends StatefulWidget {
  const _OpenPanel({required this.game, required this.close});

  final MyGame game;
  final VoidCallback close;

  @override
  State<_OpenPanel> createState() => _OpenPanelState();
}

class _OpenPanelState extends State<_OpenPanel> {
  _PanelTab _tab = _PanelTab.debug;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              for (final tab in _PanelTab.values) ...[
                if (tab != _PanelTab.values.first) const SizedBox(width: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tab = tab),
                  child: Text(tab.name, style: debugGlowStyle(_tab == tab, 26)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.close,
                child: const Icon(
                  Icons.close,
                  color: Colors.cyanAccent,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _tabBody()),
      ],
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case _PanelTab.info:
        return ValueListenableBuilder<DebugInfo>(
          valueListenable: widget.game.debugInfo,
          builder: (context, info, _) => _InfoPanelBody(info: info),
        );
      case _PanelTab.debug:
        return ValueListenableBuilder<DebugInfo>(
          valueListenable: widget.game.debugInfo,
          builder: (context, info, _) =>
              DebugPanelTab(game: widget.game, info: info),
        );
      case _PanelTab.sprites:
        return SpritesPanelTab(game: widget.game);
      case _PanelTab.level:
        return LevelsPanelTab(game: widget.game);
    }
  }
}

class _InfoPanelBody extends StatelessWidget {
  const _InfoPanelBody({required this.info});

  final DebugInfo info;

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xFFDD5050),
    fontSize: 18,
    fontFamily: 'Ava',
    height: 20 / 18,
  );

  static final TextStyle _valueStyle = TextStyle(
    color: Colors.cyan.withAlpha(500),
    fontSize: 18,
    fontFamily: 'Ava',
    height: 20 / 18,
  );

  @override
  Widget build(BuildContext context) {
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

/// Sizes to the parent (the panel slot) but only the tab/panel receives taps.
class _HitTestChildrenOnly extends SingleChildRenderObjectWidget {
  const _HitTestChildrenOnly({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHitTestChildrenOnly();
  }
}

class _RenderHitTestChildrenOnly extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }
}

/// Fills the local navigator so OpenContainer can grow, but hit-tests only the child.
class _TopLeftPassThrough extends SingleChildRenderObjectWidget {
  const _TopLeftPassThrough({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTopLeftPassThrough();
  }
}

class _RenderTopLeftPassThrough extends RenderShiftedBox {
  _RenderTopLeftPassThrough() : super(null);

  @override
  void performLayout() {
    size = constraints.biggest;
    final box = child;
    if (box == null) return;
    box.layout(constraints.loosen(), parentUsesSize: true);
    (box.parentData! as BoxParentData).offset = Offset.zero;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }
}
