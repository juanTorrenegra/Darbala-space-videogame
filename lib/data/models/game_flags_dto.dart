import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/domain/entities/game_flags.dart';

class GameFlagsDto {
  const GameFlagsDto({
    required this.title,
    required this.body,
    this.leaderboardEnabled = true,
  });

  final String title;
  final String body;
  final bool leaderboardEnabled;

  factory GameFlagsDto.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final body = json['body'];
    if (title is! String || body is! String) {
      throw const ParseFailure('Flags payload missing title or body');
    }
    return GameFlagsDto(title: title, body: body);
  }

  GameFlags toDomain() {
    return GameFlags(
      leaderboardEnabled: leaderboardEnabled,
      transmissionTitle: title.toUpperCase(),
      transmissionBody: body,
      fromRemote: true,
    );
  }
}
