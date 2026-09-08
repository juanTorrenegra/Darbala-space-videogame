/// Typed failures so UI and repositories never switch on raw [Exception]s.
sealed class AppFailure {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message, {super.cause});
}

final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {this.statusCode, super.cause});

  final int? statusCode;
}

final class ParseFailure extends AppFailure {
  const ParseFailure(super.message, {super.cause});
}

final class CacheFailure extends AppFailure {
  const CacheFailure(super.message, {super.cause});
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, {super.cause});
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.cause});
}
