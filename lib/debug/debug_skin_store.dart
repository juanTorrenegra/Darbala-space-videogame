import 'package:shared_preferences/shared_preferences.dart';

/// Local debug defaults for which skin folder each actor uses.
///
/// Uses [SharedPreferences] (on-device key/value store — not Supabase, not
/// cookies). Survives `flutter run` restarts on the same device/emulator.
class DebugSkinStore {
  DebugSkinStore._();

  static const playerKey = 'debug.skin.player';
  static const crabKey = 'debug.skin.crab';
  static const rangedKey = 'debug.skin.ranged';

  static const defaultPlayer = 'negra0metalic32sprites';
  static const defaultCrab = 'beholder';
  static const defaultRanged = 'donut';

  static Future<String> playerFolder() => _read(playerKey, defaultPlayer);
  static Future<String> crabFolder() => _read(crabKey, defaultCrab);
  static Future<String> rangedFolder() => _read(rangedKey, defaultRanged);

  static Future<void> savePlayer(String folder) => _write(playerKey, folder);
  static Future<void> saveCrab(String folder) => _write(crabKey, folder);
  static Future<void> saveRanged(String folder) => _write(rangedKey, folder);

  static Future<String> _read(String key, String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key)?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static Future<void> _write(String key, String folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, folder);
  }
}
