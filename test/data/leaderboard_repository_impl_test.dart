import 'package:flutter_test/flutter_test.dart';
import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/data/datasources/leaderboard_local_datasource.dart';
import 'package:juanshooter/data/datasources/leaderboard_remote_datasource.dart';
import 'package:juanshooter/data/models/submitted_score_dto.dart';
import 'package:juanshooter/data/repositories/leaderboard_repository_impl.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements LeaderboardRemoteDataSource {}

class _Local extends Mock implements LeaderboardLocalDataSource {}

void main() {
  late _Remote remote;
  late _Local local;
  late LeaderboardRepositoryImpl repository;

  const requestFallback = SubmittedScoreDto(
    remoteId: '',
    pilotId: 'pilot-1',
    callSign: 'MINER-7X',
    faction: 'Independent miners',
    score: 0,
  );

  setUpAll(() {
    registerFallbackValue(requestFallback);
  });

  setUp(() {
    remote = _Remote();
    local = _Local();
    repository = LeaderboardRepositoryImpl(remote: remote, local: local);
  });

  test('merges remote scores with locally cached runs and sorts by score', () async {
    when(() => remote.fetchScores()).thenAnswer(
      (_) async => [
        const SubmittedScoreDto(
          remoteId: '10',
          pilotId: 'jp-user-10',
          callSign: 'LOW',
          faction: 'Far outpost',
          score: 1000,
        ),
      ],
    );
    when(() => local.loadCachedRuns()).thenAnswer(
      (_) async => [
        const SubmittedScoreDto(
          remoteId: '101',
          pilotId: 'pilot-1',
          callSign: 'MINER-7X',
          faction: 'Independent miners',
          score: 99999,
        ),
      ],
    );

    final result = await repository.fetchTop(limit: 5);

    expect(result.isSuccess, isTrue);
    final entries = result.valueOrNull!;
    expect(entries.first.callSign, 'MINER-7X');
    expect(entries.first.isLocalPilot, isTrue);
    expect(entries[1].callSign, 'LOW');
  });

  test('falls back to cached runs when the remote outpost is down', () async {
    when(() => remote.fetchScores()).thenThrow(
      const NetworkFailure('No link to the outpost'),
    );
    when(() => local.loadCachedRuns()).thenAnswer(
      (_) async => [
        const SubmittedScoreDto(
          remoteId: 'local',
          pilotId: 'pilot-1',
          callSign: 'MINER-7X',
          faction: 'Independent miners',
          score: 12,
        ),
      ],
    );

    final result = await repository.fetchTop();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.single.score, 12);
  });

  test('submits a run and persists the receipt locally', () async {
    when(() => remote.submitScore(any())).thenAnswer(
      (_) async => const SubmittedScoreDto(
        remoteId: '101',
        pilotId: 'pilot-1',
        callSign: 'MINER-7X',
        faction: 'Independent miners',
        score: 42,
      ),
    );
    when(() => local.saveRun(any())).thenAnswer((_) async {});

    final result = await repository.submitScore(
      pilot: const PilotIdentity(id: 'pilot-1', callSign: 'MINER-7X'),
      score: 42,
    );

    expect(result, isA<Success<dynamic>>());
    verify(() => local.saveRun(any())).called(1);
  });
}
