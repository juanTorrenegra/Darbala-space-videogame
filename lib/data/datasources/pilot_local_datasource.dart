import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PilotLocalDataSource {
  Future<PilotIdentity?> loadCached();
  Future<void> saveSession(PilotIdentity identity);
  Future<void> saveLastNombre(String nombre);
  String? lastNombre();
  Future<void> clearSession();
}

class PilotLocalDataSourceImpl implements PilotLocalDataSource {
  PilotLocalDataSourceImpl(this._prefs);

  static const _idKey = 'auth.user_id';
  static const _nameKey = 'auth.display_name';
  static const _lastNombreKey = 'auth.last_nombre';

  final SharedPreferences _prefs;

  @override
  Future<PilotIdentity?> loadCached() async {
    final id = _prefs.getString(_idKey);
    final name = _prefs.getString(_nameKey);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return PilotIdentity(id: id, callSign: name);
  }

  @override
  Future<void> saveSession(PilotIdentity identity) async {
    await _prefs.setString(_idKey, identity.id);
    await _prefs.setString(_nameKey, identity.callSign);
    await saveLastNombre(identity.callSign);
  }

  @override
  Future<void> saveLastNombre(String nombre) {
    return _prefs.setString(_lastNombreKey, nombre.trim());
  }

  @override
  String? lastNombre() => _prefs.getString(_lastNombreKey);

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_idKey);
    await _prefs.remove(_nameKey);
  }
}
