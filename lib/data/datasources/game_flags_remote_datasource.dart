import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/network/api_client.dart';
import 'package:juanshooter/core/network/api_config.dart';
import 'package:juanshooter/data/models/game_flags_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class GameFlagsRemoteDataSource {
  Future<GameFlagsDto> fetch();

  /// Live flag updates. Empty by default — only realtime-capable
  /// sources (Supabase) override this.
  Stream<GameFlagsDto> watch() => const Stream.empty();
}

class GameFlagsRemoteDataSourceImpl implements GameFlagsRemoteDataSource {
  GameFlagsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Stream<GameFlagsDto> watch() => const Stream.empty();

  @override
  Future<GameFlagsDto> fetch() {
    return _client.get<GameFlagsDto>(
      ApiPaths.transmission,
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ParseFailure('Expected a transmission object');
        }
        return GameFlagsDto.fromJson(json);
      },
    );
  }
}

/// Reads flags from the `game_flags` table (PostgREST under the hood) and
/// streams live updates via Supabase Realtime.
class SupabaseGameFlagsRemoteDataSource
    implements GameFlagsRemoteDataSource {
  SupabaseGameFlagsRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _defaults = {
    'transmission_title': 'DARBALA LINK ESTABLECIDO',
    'transmission_body': '',
    'leaderboard_enabled': 'true',
  };

  @override
  Future<GameFlagsDto> fetch() async {
    try {
      final rows = await _client.from('game_flags').select('key, value');
      return _toDto(rows);
    } catch (error) {
      throw NetworkFailure('No se pudieron leer las flags', cause: error);
    }
  }

  @override
  Stream<GameFlagsDto> watch() {
    return _client
        .from('game_flags')
        .stream(primaryKey: ['key'])
        .map(_toDto);
  }

  GameFlagsDto _toDto(List<Map<String, dynamic>> rows) {
    final values = {..._defaults};
    for (final row in rows) {
      final key = row['key'];
      final value = row['value'];
      if (key is String && value is String) values[key] = value;
    }
    return GameFlagsDto(
      title: values['transmission_title']!,
      body: values['transmission_body']!,
      leaderboardEnabled: values['leaderboard_enabled'] == 'true',
    );
  }
}
