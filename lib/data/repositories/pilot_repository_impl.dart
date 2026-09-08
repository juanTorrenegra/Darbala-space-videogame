import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/core/network/supabase_config.dart';
import 'package:juanshooter/data/datasources/pilot_local_datasource.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:juanshooter/domain/repositories/pilot_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PilotRepositoryImpl implements PilotRepository {
  PilotRepositoryImpl(this._local, {SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final PilotLocalDataSource _local;
  final SupabaseClient _client;

  @override
  Future<PilotIdentity?> current() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      await _local.clearSession();
      return null;
    }
    final name = _displayNameOf(user);
    final identity = PilotIdentity(id: user.id, callSign: name);
    await _local.saveSession(identity);
    return identity;
  }

  @override
  Stream<PilotIdentity?> watch() async* {
    yield await current();
    await for (final _ in _client.auth.onAuthStateChange) {
      yield await current();
    }
  }

  @override
  Future<Result<PilotIdentity>> signUp({
    required String nombre,
    required String password,
  }) async {
    final parsed = _validate(nombre, password);
    if (parsed != null) return Failure(parsed);

    try {
      await _client.functions.invoke(
        'create-player',
        body: {
          'nombre': nombre.trim(),
          'password': password,
        },
      );
      return signIn(nombre: nombre, password: password);
    } on FunctionException catch (error) {
      return Failure(AuthFailure(_mapFunction(error), cause: error));
    } on AuthException catch (error) {
      return Failure(AuthFailure(_mapAuth(error), cause: error));
    } catch (error) {
      return Failure(NetworkFailure('No se pudo crear la cuenta', cause: error));
    }
  }

  @override
  Future<Result<PilotIdentity>> signIn({
    required String nombre,
    required String password,
  }) async {
    final parsed = _validate(nombre, password);
    if (parsed != null) return Failure(parsed);

    try {
      final response = await _client.auth.signInWithPassword(
        email: SupabaseConfig.emailFromNombre(nombre),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Failure(AuthFailure('No se pudo entrar'));
      }
      final identity = PilotIdentity(
        id: user.id,
        callSign: _displayNameOf(user, fallback: nombre),
      );
      await _local.saveSession(identity);
      return Success(identity);
    } on AuthException catch (error) {
      return Failure(AuthFailure(_mapAuth(error), cause: error));
    } catch (error) {
      return Failure(NetworkFailure('No se pudo entrar', cause: error));
    }
  }

  @override
  Future<PilotIdentity> updateCallSign(String callSign) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No hay sesión');
    }
    final next = callSign.trim().toUpperCase();
    await _client
        .from('profiles')
        .update({
          'display_name': next,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': next}),
    );
    final identity = PilotIdentity(id: user.id, callSign: next);
    await _local.saveSession(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _local.clearSession();
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _client.rpc('delete_own_account');
      await signOut();
      return const Success(null);
    } catch (error) {
      return Failure(
        NetworkFailure('No se pudo borrar la cuenta', cause: error),
      );
    }
  }

  AuthFailure? _validate(String nombre, String password) {
    final trimmed = nombre.trim();
    if (trimmed.length < 2 || trimmed.length > 24) {
      return const AuthFailure('El nombre debe tener entre 2 y 24 caracteres');
    }
    final slug = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (slug.isEmpty) {
      return const AuthFailure('El nombre necesita letras o números');
    }
    if (password.length < 6) {
      return const AuthFailure('La contraseña debe tener al menos 6 caracteres');
    }
    return null;
  }

  String _displayNameOf(User user, {String? fallback}) {
    final meta = user.userMetadata?['display_name'];
    if (meta is String && meta.trim().isNotEmpty) return meta.trim();
    return (fallback ?? 'PILOTO').trim().toUpperCase();
  }

  String _mapAuth(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('user already')) {
      return 'Ese nombre ya está registrado. Usa Entrar.';
    }
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'Nombre o contraseña incorrectos';
    }
    if (message.contains('is invalid') || message.contains('invalid email')) {
      return 'No se pudo crear la cuenta. Prueba otro nombre.';
    }
    if (message.contains('rate limit') || message.contains('email rate')) {
      return 'Demasiados intentos. Espera un minuto y prueba de nuevo.';
    }
    return error.message;
  }

  String _mapFunction(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'] ?? details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    return 'No se pudo crear la cuenta';
  }
}
