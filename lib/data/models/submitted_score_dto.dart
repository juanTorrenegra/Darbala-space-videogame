import 'package:juanshooter/core/error/app_failure.dart';
import 'package:juanshooter/domain/entities/leaderboard_entry.dart';

class SubmittedScoreDto {
  const SubmittedScoreDto({
    required this.remoteId,
    required this.pilotId,
    required this.callSign,
    required this.faction,
    required this.score,
  });

  final String remoteId;
  final String pilotId;
  final String callSign;
  final String faction;
  final int score;

  factory SubmittedScoreDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null) {
      throw const ParseFailure('Submit payload missing id');
    }
    return SubmittedScoreDto(
      remoteId: '$id',
      pilotId: json['pilotId'] as String? ?? '',
      callSign: json['callSign'] as String? ?? 'UNKNOWN',
      faction: json['faction'] as String? ?? 'Independent',
      score: asInt(json['score']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': '$callSign run',
      'body': 'score:$score faction:$faction',
      'userId': 1,
      'pilotId': pilotId,
      'callSign': callSign,
      'faction': faction,
      'score': score,
    };
  }

  factory SubmittedScoreDto.fromCache(Map<String, dynamic> json) {
    return SubmittedScoreDto(
      remoteId: json['remoteId'] as String? ?? '',
      pilotId: json['pilotId'] as String? ?? '',
      callSign: json['callSign'] as String? ?? 'UNKNOWN',
      faction: json['faction'] as String? ?? 'Independent',
      score: asInt(json['score']),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'remoteId': remoteId,
      'pilotId': pilotId,
      'callSign': callSign,
      'faction': faction,
      'score': score,
    };
  }

  LeaderboardEntry toDomain({required bool isLocalPilot}) {
    return LeaderboardEntry(
      pilotId: pilotId,
      callSign: callSign,
      faction: faction,
      score: score,
      isLocalPilot: isLocalPilot,
      remoteRecordId: remoteId,
    );
  }

  static int asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
