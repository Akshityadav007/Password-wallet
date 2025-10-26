// Dependency injection setup (GetIt)

import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/master_password_service.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:logging/logging.dart';

// Core & Data
import 'data/sources/local/db_service.dart';
import 'data/sources/local/secure_storage.dart';

// Domain
import 'domain/interfaces/crypto_service.dart';
import 'domain/interfaces/backup_service.dart';
import 'domain/repositories/password_repository.dart';

// Data Repositories
import 'data/repositories/password_repository_impl.dart';

// Services
import 'services/crypto_service_impl.dart';
import 'services/encryption_service.dart';
import 'services/auth_service.dart';
import 'services/backup_service_impl.dart';
import 'services/biometric_service.dart';
import 'services/lock_service.dart';
import 'services/session_service.dart';

final GetIt locator = GetIt.instance;
final _logger = Logger('injection');

Future<void> configureDependencies(SodiumSumo sodiumSumo) async {
  // Core services
  locator.registerLazySingleton<DbService>(() => DbService());
  locator.registerLazySingleton<SecureStorage>(() => SecureStorage());

  // Data repositories
  locator.registerLazySingleton<PasswordRepository>(
    () => PasswordRepositoryImpl(locator<DbService>()),
  );

  locator.registerLazySingleton<MasterPasswordService>(
    () => MasterPasswordService(locator(), locator()),
  );

  // Crypto & Security
  locator.registerLazySingleton<CryptoService>(
    () => CryptoServiceImpl(sodiumSumo),
  );
  locator.registerLazySingleton<BiometricService>(() => BiometricService());
  locator.registerLazySingleton<EncryptionService>(
    () => EncryptionService(locator()),
  );
  locator.registerLazySingleton<AuthService>(
    () => AuthService(
      crypto: locator(),
      biometricService: locator(),
      secureStorage: locator(),
    ),
  );

  // Backup service
  locator.registerLazySingleton<BackupService>(
    () => BackupServiceImpl(
      locator<PasswordRepository>(),
      locator<CryptoService>(),
    ),
  );

  // Lock service
  locator.registerLazySingleton<LockService>(() => LockService());

  // Session service
  locator.registerLazySingleton<SessionService>(() => SessionService());


  _logger.info('✅ All services registered successfully');
}
