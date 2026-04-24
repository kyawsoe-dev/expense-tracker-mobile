import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userEmailKey = 'user_email';
  static const _userNameKey = 'user_name';
  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> writeTokens(
      {required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> writeUserProfile({String? email, String? name}) async {
    if (email != null && email.trim().isNotEmpty) {
      await _storage.write(key: _userEmailKey, value: email);
    } else {
      await _storage.delete(key: _userEmailKey);
    }
    if (name != null && name.trim().isNotEmpty) {
      await _storage.write(key: _userNameKey, value: name);
    } else {
      await _storage.delete(key: _userNameKey);
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> readUserEmail() => _storage.read(key: _userEmailKey);

  Future<String?> readUserName() => _storage.read(key: _userNameKey);

  Future<void> writeThemeMode(String themeMode) =>
      _storage.write(key: _themeModeKey, value: themeMode);

  Future<String?> readThemeMode() => _storage.read(key: _themeModeKey);

  Future<void> writeValue({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  Future<String?> readValue(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);

  Future<void> clear() async {
    final savedThemeMode = await _storage.read(key: _themeModeKey);
    await _storage.deleteAll();
    if (savedThemeMode != null && savedThemeMode.isNotEmpty) {
      await _storage.write(key: _themeModeKey, value: savedThemeMode);
    }
  }
}
