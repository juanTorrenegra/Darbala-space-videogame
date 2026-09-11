import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/domain/entities/game_flags.dart';

abstract class GameFlagsRepository {
  Future<Result<GameFlags>> fetch();

  /// Live flag updates. Empty stream when the source cannot push changes.
  Stream<GameFlags> watch();
}
