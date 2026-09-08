import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/data/datasources/leaderboard_local_datasource.dart';
import 'package:juanshooter/data/datasources/leaderboard_remote_datasource.dart';
import 'package:juanshooter/data/models/submitted_score_dto.dart';
import 'package:juanshooter/domain/entities/leaderboard_entry.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:juanshooter/domain/repositories/leaderboard_repository.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl({
    required LeaderboardRemoteDataSource remote,
    required LeaderboardLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final LeaderboardRemoteDataSource _remote;
  final LeaderboardLocalDataSource _local;

  @override
  Future<Result<List<LeaderboardEntry>>> fetchTop({int limit = 10}) async {
    try {
      final remotePilots = await _remote.fetchScores();
      final localRuns = await _local.loadCachedRuns();
      final entries = [
        ...remotePilots.map((dto) => dto.toDomain(isLocalPilot: false)),
        ...localRuns.map((dto) => dto.toDomain(isLocalPilot: true)),
      ];
      return Success(_bestPerPilot(entries, limit));
    } on AppFailure catch (failure) {
      return _cachedOnly(failure, limit);
    } catch (error) {
      return _cachedOnly(
        NetworkFailure('Could not reach the ranking outpost', cause: error),
        limit,
      );
    }
  }

  Future<Result<List<LeaderboardEntry>>> _cachedOnly(
    AppFailure failure,
    int limit,
  ) async {
    try {
      final localRuns = await _local.loadCachedRuns();
      if (localRuns.isEmpty) return Failure(failure);
      final entries = localRuns
          .map((dto) => dto.toDomain(isLocalPilot: true))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return Success(_bestPerPilot(entries, limit));
    } on AppFailure catch (cacheFailure) {
      return Failure(cacheFailure);
    }
  }

  List<LeaderboardEntry> _bestPerPilot(List<LeaderboardEntry> entries, int limit) {
    final byPilot = <String, LeaderboardEntry>{};
    for (final entry in entries) {
      final previous = byPilot[entry.pilotId];
      if (previous == null || entry.score > previous.score) {
        byPilot[entry.pilotId] = entry;
      }
    }
    final ranked = byPilot.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).toList();
  }

  @override
  Future<Result<LeaderboardEntry>> submitScore({
    required PilotIdentity pilot,
    required int score,
  }) async {
    final request = SubmittedScoreDto(
      remoteId: '',
      pilotId: pilot.id,
      callSign: pilot.callSign,
      faction: 'Independent miners',
      score: score,
    );

    try {
      final receipt = await _remote.submitScore(request);
      await _local.saveRun(receipt);
      return Success(receipt.toDomain(isLocalPilot: true));
    } on AppFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(
        NetworkFailure('Score transmission failed', cause: error),
      );
    }
  }
}
