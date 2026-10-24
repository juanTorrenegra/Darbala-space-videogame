import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:juanshooter/debug/debug_skin_store.dart';
import 'package:juanshooter/debug/skin_catalog.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/overlays/debug_panel_tab.dart';
import 'package:juanshooter/weapons/ammo.dart';

enum SpriteSubTab { player, crab, ranged, ammo }

class SpritesPanelTab extends StatefulWidget {
  const SpritesPanelTab({super.key, required this.game});

  final MyGame game;

  @override
  State<SpritesPanelTab> createState() => _SpritesPanelTabState();
}

class _SpritesPanelTabState extends State<SpritesPanelTab>
    with SingleTickerProviderStateMixin {
  SpriteSubTab _sub = SpriteSubTab.player;
  List<SkinFolderInfo> _skins = const [];
  String? _savedPlayer;
  String? _savedCrab;
  String? _savedRanged;
  bool _loading = true;
  late final AnimationController _pop;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _popScale = Tween<double>(begin: 1, end: 1.16).animate(
      CurvedAnimation(parent: _pop, curve: Curves.easeOut),
    );
    _reload();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final skins = await SkinCatalog.load();
    final player = await DebugSkinStore.playerFolder();
    final crab = await DebugSkinStore.crabFolder();
    final ranged = await DebugSkinStore.rangedFolder();
    if (!mounted) return;
    setState(() {
      _skins = skins;
      _savedPlayer = player;
      _savedCrab = crab;
      _savedRanged = ranged;
      _loading = false;
    });
  }

  String get _appliedFolder {
    switch (_sub) {
      case SpriteSubTab.player:
        return widget.game.shipSkinFolder;
      case SpriteSubTab.crab:
        return widget.game.crabSkinFolder;
      case SpriteSubTab.ranged:
        return widget.game.rangedSkinFolder;
      case SpriteSubTab.ammo:
        return '';
    }
  }

  String? get _savedFolder {
    switch (_sub) {
      case SpriteSubTab.player:
        return _savedPlayer;
      case SpriteSubTab.crab:
        return _savedCrab;
      case SpriteSubTab.ranged:
        return _savedRanged;
      case SpriteSubTab.ammo:
        return null;
    }
  }

  Future<void> _preview(String folder) async {
    switch (_sub) {
      case SpriteSubTab.player:
        await widget.game.applyPlayerSkinFolder(folder);
      case SpriteSubTab.crab:
        await widget.game.applyCrabSkinFolder(folder);
      case SpriteSubTab.ranged:
        await widget.game.applyRangedSkinFolder(folder);
      case SpriteSubTab.ammo:
        return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveDefault() async {
    _pop.forward(from: 0).then((_) {
      if (mounted) _pop.reverse();
    });
    switch (_sub) {
      case SpriteSubTab.player:
        await DebugSkinStore.savePlayer(widget.game.shipSkinFolder);
        _savedPlayer = widget.game.shipSkinFolder;
      case SpriteSubTab.crab:
        await DebugSkinStore.saveCrab(widget.game.crabSkinFolder);
        _savedCrab = widget.game.crabSkinFolder;
      case SpriteSubTab.ranged:
        await DebugSkinStore.saveRanged(widget.game.rangedSkinFolder);
        _savedRanged = widget.game.rangedSkinFolder;
      case SpriteSubTab.ammo:
        return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              for (final tab in SpriteSubTab.values) ...[
                if (tab != SpriteSubTab.values.first) const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sub = tab),
                  child: Text(
                    tab.name,
                    style: debugGlowStyle(_sub == tab, 22),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _sub == SpriteSubTab.ammo
              ? _AmmoStrip(game: widget.game)
              : _loading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Stack(
                  children: [
                    _SkinGrid(
                      skins: _skins,
                      selected: _appliedFolder,
                      saved: _savedFolder,
                      popScale: _popScale,
                      onTap: _preview,
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _saveDefault,
                        child: ScaleTransition(
                          scale: _popScale,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('set', style: debugGlowStyle(true, 28)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SkinGrid extends StatelessWidget {
  const _SkinGrid({
    required this.skins,
    required this.selected,
    required this.saved,
    required this.popScale,
    required this.onTap,
  });

  final List<SkinFolderInfo> skins;
  final String selected;
  final String? saved;
  final Animation<double> popScale;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(right: 36, bottom: 28),
      itemCount: skins.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final skin = skins[index];
        final isSelected = skin.name == selected;
        Widget tile = DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x2210A0B0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.cyanAccent
                    : const Color(0x6670C8D0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(color: Colors.cyanAccent, blurRadius: 8),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      skin.twoLineLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontFamily: 'Megatrans',
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 4,
                  child: Text(
                    '${skin.spriteCount}',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.cyanAccent,
                      fontSize: 16,
                      fontFamily: 'Megatrans',
                      height: 1,
                    ),
                  ),
                ),
                if (skin.name == saved)
                  const Positioned(
                    bottom: 2,
                    left: 4,
                    child: Text(
                      'DEF',
                      style: TextStyle(
                        color: Color(0xAA7FFFF8),
                        fontSize: 14,
                        fontFamily: 'Ava',
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
        );
        if (isSelected) {
          tile = ScaleTransition(scale: popScale, child: tile);
        }
        return GestureDetector(
          onTap: () => onTap(skin.name),
          child: tile,
        );
      },
    );
  }
}

class _AmmoStrip extends StatefulWidget {
  const _AmmoStrip({required this.game});

  final MyGame game;

  @override
  State<_AmmoStrip> createState() => _AmmoStripState();
}

class _AmmoStripState extends State<_AmmoStrip> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kind in AmmoKind.values)
            _AmmoTile(
              kind: kind,
              selected: widget.game.selectedAmmo == kind,
              onTap: () => setState(() => widget.game.selectedAmmo = kind),
            ),
        ],
      ),
    );
  }
}

class _AmmoTile extends StatelessWidget {
  const _AmmoTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AmmoKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _AmmoPainter(kind: kind, selected: selected),
        child: const SizedBox(width: 46, height: 46),
      ),
    );
  }
}

class _AmmoPainter extends CustomPainter {
  _AmmoPainter({required this.kind, required this.selected});

  final AmmoKind kind;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = selected ? const Color(0x5522E0E8) : const Color(0x2210A0B0),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = selected ? const Color(0xCC7FFFF8) : const Color(0x6670C8D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1.0,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    switch (kind) {
      case AmmoKind.laser:
        final laser = Paint()..color = const Color(0xFF7FFFF8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 28, height: 5),
            const Radius.circular(2),
          ),
          laser,
        );
        final path = Path()
          ..moveTo(10, -4)
          ..lineTo(16, 0)
          ..lineTo(10, 4)
          ..close();
        canvas.drawPath(path, laser);
      case AmmoKind.needle:
        canvas.drawCircle(Offset.zero, 4.5, Paint()..color = const Color(0xFFEAF4FF));
      case AmmoKind.plasma:
        canvas.drawCircle(Offset.zero, 11, Paint()..color = const Color(0x55E060FF));
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 18, height: 8),
          Paint()..color = const Color(0xAAFF9CFF),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 3.5),
          Paint()..color = const Color(0xFFF5E9FF),
        );
      case AmmoKind.ion:
        final stroke = Paint()
          ..color = const Color(0xFFFFC94A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(Offset.zero, 11, Paint()..color = const Color(0x44FFB020));
        canvas.drawCircle(Offset.zero, 8, stroke);
        canvas.drawCircle(Offset.zero, 2.2, Paint()..color = const Color(0xCCFFE8A0));
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(math.cos(a) * 5, math.sin(a) * 5),
            Offset(math.cos(a) * 9.5, math.sin(a) * 9.5),
            stroke,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmmoPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.selected != selected;
  }
}
