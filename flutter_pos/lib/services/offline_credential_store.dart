import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OfflineCredentialStore {
  Future<void> save({required String staffId, required String password});
  Future<String?> read({required String staffId});
  Future<void> remove({required String staffId});
}

class SecureOfflineCredentialStore implements OfflineCredentialStore {
  static const String _keyPrefix = 'offline_staff_password_v1_';
  final FlutterSecureStorage _storage;

  SecureOfflineCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _key(String staffId) => '$_keyPrefix$staffId';

  @override
  Future<void> save({required String staffId, required String password}) =>
      _storage.write(key: _key(staffId), value: password);

  @override
  Future<String?> read({required String staffId}) =>
      _storage.read(key: _key(staffId));

  @override
  Future<void> remove({required String staffId}) =>
      _storage.delete(key: _key(staffId));
}
