import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeycloakService {
  static const String _discoveryUrl =
      'YOUR_KEYCLOAK_URL/realms/YOUR_REALM/.well-known/openid-configuration';
  static const String _clientId = 'YOUR_CLIENT_ID';
  static const String _redirectUrl = 'com.example.expense_tracker://callback';
  static const String _postLogoutRedirectUrl =
      'com.example.expense_tracker://callback';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'keycloak_access_token';
  static const String _refreshTokenKey = 'keycloak_refresh_token';
  static const String _idTokenKey = 'keycloak_id_token';

  Future<AuthorizationTokenResponse?> authenticateWithGoogle() async {
    return _authenticateWithProvider('google');
  }

  Future<AuthorizationTokenResponse?> authenticateWithGitHub() async {
    return _authenticateWithProvider('github');
  }

  Future<AuthorizationTokenResponse?> _authenticateWithProvider(
      String provider) async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          scopes: ['openid', 'profile', 'email'],
          additionalParameters: {
            'kc_idp_hint': provider,
          },
        ),
      );

      await _storage.write(
          key: _accessTokenKey, value: result.accessToken);
      await _storage.write(
          key: _refreshTokenKey, value: result.refreshToken);
      await _storage.write(key: _idTokenKey, value: result.idToken);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<TokenResponse?> refreshToken(String refreshToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          refreshToken: refreshToken,
          scopes: ['openid', 'profile', 'email'],
        ),
      );

      await _storage.write(
          key: _accessTokenKey, value: result.accessToken);
      await _storage.write(
          key: _refreshTokenKey, value: result.refreshToken);
      await _storage.write(key: _idTokenKey, value: result.idToken);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final idToken = await _storage.read(key: _idTokenKey);
      if (idToken != null) {
        await _appAuth.endSession(
          EndSessionRequest(
            discoveryUrl: _discoveryUrl,
            idTokenHint: idToken,
            postLogoutRedirectUrl: _postLogoutRedirectUrl,
          ),
        );
      }
    } finally {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _idTokenKey);
    }
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
