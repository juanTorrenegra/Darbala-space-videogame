import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/network/api_client.dart';
import 'package:juanshooter/core/network/api_config.dart';
import 'package:juanshooter/data/models/json_placeholder_user_dto.dart';
import 'package:juanshooter/data/models/submitted_score_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LeaderboardRemoteDataSource {
  Future<List<SubmittedScoreDto>> fetchScores();
  Future<SubmittedScoreDto> submitScore(SubmittedScoreDto request);
}

/// JSONPlaceholder stand-in kept for offline tests without Supabase.
class JsonPlaceholderLeaderboardRemoteDataSource
    implements LeaderboardRemoteDataSource {
  JsonPlaceholderLeaderboardRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<SubmittedScoreDto>> fetchScores() async {
    final users = await _client.get<List<JsonPlaceholderUserDto>>(
      ApiPaths.users,
      parse: (json) {
        if (json is! List) {
          throw const ParseFailure('Expected a list of pilots');
        }
        return json
            .whereType<Map>()
            .map(
              (item) => JsonPlaceholderUserDto.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      },
    );
    return users
        .map((user) {
          final entry = user.toDomain();
          return SubmittedScoreDto(
            remoteId: entry.remoteRecordId ?? '',
            pilotId: entry.pilotId,
            callSign: entry.callSign,
            faction: entry.faction,
            score: entry.score,
          );
        })
        .toList();
  }

  @override
  Future<SubmittedScoreDto> submitScore(SubmittedScoreDto request) {
    return _client.post<SubmittedScoreDto>(
      ApiPaths.posts,
      body: request.toJson(),
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ParseFailure('Expected a score receipt object');
        }
        return SubmittedScoreDto.fromJson({
          ...request.toCacheJson(),
          'id': json['id'],
        });
      },
    );
  }
}

class SupabaseLeaderboardRemoteDataSource
    implements LeaderboardRemoteDataSource {
  SupabaseLeaderboardRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<SubmittedScoreDto>> fetchScores() async {
    try {
      final rows = await _client
          .from('leaderboard_scores')
          .select('id, user_id, display_name, score')
          .order('score', ascending: false)
          .limit(1000);
      final seen = <String>{};
      final result = <SubmittedScoreDto>[];
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final userId = map['user_id'] as String? ?? '';
        if (userId.isEmpty || !seen.add(userId)) continue;
        result.add(
          SubmittedScoreDto(
            remoteId: '${map['id']}',
            pilotId: userId,
            callSign: map['display_name'] as String? ?? 'PILOTO',
            faction: 'Darbala',
            score: SubmittedScoreDto.asInt(map['score']),
          ),
        );
      }
      return result;
    } catch (error) {
      throw NetworkFailure('No se pudo leer el ranking', cause: error);
    }
  }

  @override
  Future<SubmittedScoreDto> submitScore(SubmittedScoreDto request) async {
    try {
      final row = await _client
          .from('leaderboard_scores')
          .insert({
            'user_id': request.pilotId,
            'display_name': request.callSign,
            'score': request.score,
          })
          .select()
          .single();
      return SubmittedScoreDto(
        remoteId: '${row['id']}',
        pilotId: request.pilotId,
        callSign: request.callSign,
        faction: request.faction,
        score: request.score,
      );
    } catch (error) {
      throw NetworkFailure('No se pudo enviar el puntaje', cause: error);
    }
  }
}
