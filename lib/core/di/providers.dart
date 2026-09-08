import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/network/api_client.dart';
import 'package:juanshooter/core/network/api_config.dart';
import 'package:juanshooter/data/datasources/game_flags_remote_datasource.dart';
import 'package:juanshooter/data/datasources/leaderboard_local_datasource.dart';
import 'package:juanshooter/data/datasources/leaderboard_remote_datasource.dart';
import 'package:juanshooter/data/datasources/pilot_local_datasource.dart';
import 'package:juanshooter/data/repositories/game_flags_repository_impl.dart';
import 'package:juanshooter/data/repositories/leaderboard_repository_impl.dart';
import 'package:juanshooter/data/repositories/pilot_repository_impl.dart';
import 'package:juanshooter/domain/entities/game_flags.dart';
import 'package:juanshooter/domain/entities/leaderboard_entry.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:juanshooter/domain/repositories/game_flags_repository.dart';
import 'package:juanshooter/domain/repositories/leaderboard_repository.dart';
import 'package:juanshooter/domain/repositories/pilot_repository.dart';
import 'package:juanshooter/domain/usecases/fetch_game_flags.dart';
import 'package:juanshooter/domain/usecases/fetch_leaderboard.dart';
import 'package:juanshooter/domain/usecases/submit_run_score.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Override sharedPreferencesProvider in ProviderScope',
  );
});

final apiConfigProvider = Provider<ApiConfig>((ref) {
  return ApiConfig.fromEnvironment();
});

final pilotLocalDataSourceProvider = Provider<PilotLocalDataSource>((ref) {
  return PilotLocalDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

final pilotRepositoryProvider = Provider<PilotRepository>((ref) {
  return PilotRepositoryImpl(ref.watch(pilotLocalDataSourceProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(
    config: ref.watch(apiConfigProvider),
    pilotId: () {
      final cached = ref.read(sharedPreferencesProvider).getString('pilot.id');
      return cached ?? 'anonymous';
    },
    accessToken: () => null,
  );
});

final leaderboardRemoteDataSourceProvider =
    Provider<LeaderboardRemoteDataSource>((ref) {
  return SupabaseLeaderboardRemoteDataSource();
});

final leaderboardLocalDataSourceProvider =
    Provider<LeaderboardLocalDataSource>((ref) {
  return LeaderboardLocalDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(
    remote: ref.watch(leaderboardRemoteDataSourceProvider),
    local: ref.watch(leaderboardLocalDataSourceProvider),
  );
});

final gameFlagsRemoteDataSourceProvider =
    Provider<GameFlagsRemoteDataSource>((ref) {
  return GameFlagsRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final gameFlagsRepositoryProvider = Provider<GameFlagsRepository>((ref) {
  return GameFlagsRepositoryImpl(ref.watch(gameFlagsRemoteDataSourceProvider));
});

final fetchLeaderboardProvider = Provider<FetchLeaderboard>((ref) {
  return FetchLeaderboard(ref.watch(leaderboardRepositoryProvider));
});

final submitRunScoreProvider = Provider<SubmitRunScore>((ref) {
  return SubmitRunScore(ref.watch(leaderboardRepositoryProvider));
});

final fetchGameFlagsProvider = Provider<FetchGameFlags>((ref) {
  return FetchGameFlags(ref.watch(gameFlagsRepositoryProvider));
});

final currentPilotProvider = StreamProvider<PilotIdentity?>((ref) {
  return ref.watch(pilotRepositoryProvider).watch();
});

final gameFlagsProvider = FutureProvider<GameFlags>((ref) async {
  final result = await ref.watch(fetchGameFlagsProvider).call();
  return result.when(
    success: (flags) => flags,
    failure: (_) => GameFlags.offlineFallback(),
  );
});

class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? errorMessage;

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LeaderboardController extends Notifier<LeaderboardState> {
  @override
  LeaderboardState build() => const LeaderboardState();

  Future<void> load({int limit = 10}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await ref.read(fetchLeaderboardProvider).call(limit: limit);
    state = result.when(
      success: (entries) => LeaderboardState(entries: entries),
      failure: (error) => LeaderboardState(errorMessage: error.message),
    );
  }
}

final leaderboardControllerProvider =
    NotifierProvider<LeaderboardController, LeaderboardState>(
  LeaderboardController.new,
);

sealed class ScoreSubmitState {
  const ScoreSubmitState();
}

final class ScoreSubmitIdle extends ScoreSubmitState {
  const ScoreSubmitIdle();
}

final class ScoreSubmitInFlight extends ScoreSubmitState {
  const ScoreSubmitInFlight(this.score);
  final int score;
}

final class ScoreSubmitSuccess extends ScoreSubmitState {
  const ScoreSubmitSuccess(this.entry);
  final LeaderboardEntry entry;
}

final class ScoreSubmitFailure extends ScoreSubmitState {
  const ScoreSubmitFailure(this.message);
  final String message;
}

class ScoreSubmitController extends Notifier<ScoreSubmitState> {
  @override
  ScoreSubmitState build() => const ScoreSubmitIdle();

  Future<void> submit(int score) async {
    state = ScoreSubmitInFlight(score);
    final pilot = await ref.read(pilotRepositoryProvider).current();
    if (pilot == null) {
      state = const ScoreSubmitFailure('Necesitas una cuenta para enviar el puntaje');
      return;
    }
    final result = await ref.read(submitRunScoreProvider).call(
          pilot: pilot,
          score: score,
        );
    state = result.when(
      success: ScoreSubmitSuccess.new,
      failure: (error) => ScoreSubmitFailure(error.message),
    );
  }

  void reset() => state = const ScoreSubmitIdle();
}

final scoreSubmitControllerProvider =
    NotifierProvider<ScoreSubmitController, ScoreSubmitState>(
  ScoreSubmitController.new,
);
