import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/data/datasources/game_flags_remote_datasource.dart';
import 'package:juanshooter/domain/entities/game_flags.dart';
import 'package:juanshooter/domain/repositories/game_flags_repository.dart';

class GameFlagsRepositoryImpl implements GameFlagsRepository {
  GameFlagsRepositoryImpl(this._remote);

  final GameFlagsRemoteDataSource _remote;

  @override
  Future<Result<GameFlags>> fetch() async {
    try {
      final dto = await _remote.fetch();
      return Success(dto.toDomain());
    } on AppFailure {
      return Success(GameFlags.offlineFallback());
    } catch (_) {
      return Success(GameFlags.offlineFallback());
    }
  }

  @override
  Stream<GameFlags> watch() {
    return _remote.watch().map((dto) => dto.toDomain()).handleError((_) {});
  }
}
