import 'package:dio/dio.dart';
import '../navigation/app_router.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;

  AuthInterceptor(this.dio, this.tokenStorage);

  void _redirectToLogin() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final access = await tokenStorage.readAccessToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 &&
        path != '/auth/refresh' &&
        path != '/auth/login' &&
        path != '/auth/register') {
      final refresh = await tokenStorage.readRefreshToken();
      if (refresh != null) {
        try {
          final response = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
          final newAccess = response.data['accessToken'] as String;
          final newRefresh = response.data['refreshToken'] as String;

          await tokenStorage.writeTokens(accessToken: newAccess, refreshToken: newRefresh);

          final retryRequest = err.requestOptions;
          retryRequest.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await dio.fetch(retryRequest);
          return handler.resolve(retryResponse);
        } catch (_) {
          await tokenStorage.clear();
          _redirectToLogin();
        }
      } else {
        await tokenStorage.clear();
        _redirectToLogin();
      }
    }

    handler.next(err);
  }
}
