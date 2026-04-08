import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:juanshooter/game.dart';
import 'package:flutter/services.dart';

import 'package:juanshooter/overlays/debug_menu.dart';
import 'package:juanshooter/overlays/hud_decoration_overlay.dart';

import 'package:juanshooter/overlays/main_menu.dart';
import 'package:juanshooter/overlays/score_board.dart';
import 'package:juanshooter/utils/game_utils.dart'; //landscape mode

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FontLoaderUtil.loadAllFontsForTesting().then((_) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).then((_) {
      Flame.device.setLandscapeRightOnly();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]).then((_) {
        runApp(
          GameWidget<MyGame>.controlled(
            gameFactory: MyGame.new,
            overlayBuilderMap: {
              'MainMenu': (_, game) => VisorOverlay(game: game),
              "HudDecoration": (_, game) => HudDecorationOverlay(game: game),
              'DebugMenu': (_, game) => DebugMenu(game: game),
              'ScoreBoard': (_, game) => ScoreBoard(game: game),
              //'GameOver': (_, game) => GameOver(game: game),
            },
            initialActiveOverlays: const [
              //'HudDecoration',
              'MainMenu',
              //'ScoreBoard',
            ],
          ),
        );
      });
    });
  });
}
