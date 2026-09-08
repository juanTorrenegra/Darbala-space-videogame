import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';

abstract class PilotRepository {
  Future<PilotIdentity?> current();
  Stream<PilotIdentity?> watch();
  Future<Result<PilotIdentity>> signUp({
    required String nombre,
    required String password,
  });
  Future<Result<PilotIdentity>> signIn({
    required String nombre,
    required String password,
  });
  Future<PilotIdentity> updateCallSign(String callSign);
  Future<void> signOut();
  Future<Result<void>> deleteAccount();
}
