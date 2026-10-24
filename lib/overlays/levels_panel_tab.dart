import 'package:flutter/material.dart';
import 'package:juanshooter/game.dart';
import 'package:juanshooter/levels/sector_level.dart';

class LevelsPanelTab extends StatefulWidget {
  const LevelsPanelTab({super.key, required this.game});

  final MyGame game;

  @override
  State<LevelsPanelTab> createState() => _LevelsPanelTabState();
}

class _LevelsPanelTabState extends State<LevelsPanelTab> {
  static const int _count = 8;

  MyGame get game => widget.game;

  int? get _currentOneBased {
    final level = game.currentLevel;
    if (level is SectorLevel) return level.campaignIndex + 1;
    return null;
  }

  void _jumpToLevel(int oneBased) {
    if (game.overlays.isActive('MainMenu')) {
      game.overlays.remove('MainMenu');
    }
    if (!game.overlays.isActive('HudDecoration')) {
      game.overlays.add('HudDecoration');
    }
    if (!game.overlays.isActive('ScoreBoard')) {
      game.overlays.add('ScoreBoard');
    }
    game.resumeEngine();
    game.resumeBgmMusic();
    game.startLevel(SectorLevel.at(oneBased - 1));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentOneBased;
    return GridView.builder(
      itemCount: _count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final oneBased = index + 1;
        final selected = current == oneBased;
        return GestureDetector(
          onTap: () => _jumpToLevel(oneBased),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x2210A0B0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.cyanAccent : const Color(0x6670C8D0),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? const [BoxShadow(color: Colors.cyanAccent, blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                'level $oneBased',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Megatrans',
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
