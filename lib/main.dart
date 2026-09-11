import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/game.dart';

import 'package:juanshooter/overlays/debug_menu.dart';
import 'package:juanshooter/overlays/hud_decoration_overlay.dart';
import 'package:juanshooter/overlays/leaderboard_overlay.dart';
import 'package:juanshooter/overlays/main_menu.dart';
import 'package:juanshooter/overlays/score_board.dart';
import 'package:juanshooter/overlays/score_transmit_overlay.dart';
import 'package:juanshooter/utils/game_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juanshooter/core/network/supabase_config.dart';
import 'package:juanshooter/overlays/create_account_overlay.dart';
import 'package:juanshooter/overlays/flag_admin_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FontLoaderUtil.loadAllFontsForTesting();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  Flame.device.setLandscapeRightOnly();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const JuanShooterApp(),
    ),
  );
}

class JuanShooterApp extends ConsumerWidget {
  const JuanShooterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: MyGame.logicalWidth,
              height: MyGame.logicalHeight,
              child: GameWidget<MyGame>.controlled(
                gameFactory: () => MyGame(
                  onRunEnded: (score) {
                    ref
                        .read(scoreSubmitControllerProvider.notifier)
                        .submit(score);
                  },
                ),
                overlayBuilderMap: {
                  'MainMenu': (_, game) => VisorOverlay(game: game),
                  'HudDecoration': (_, game) =>
                      HudDecorationOverlay(game: game),
                  'DebugMenu': (_, game) => DebugMenu(game: game),
                  'ScoreBoard': (_, game) => ScoreBoard(game: game),
                  'Leaderboard': (_, game) => LeaderboardOverlay(game: game),
                  'ScoreTransmit': (_, game) =>
                      ScoreTransmitOverlay(game: game),
                  'CreateAccount': (_, game) =>
                      CreateAccountOverlay(game: game),
                  'FlagAdmin': (_, game) => FlagAdminOverlay(game: game),
                },
                initialActiveOverlays: const [
                  'MainMenu',
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
