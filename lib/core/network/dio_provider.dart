import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_store.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final offlineStoreProvider = Provider<OfflineStore>(
    (ref) => OfflineStore(ref.read(tokenStorageProvider)));

const _defaultApiBaseUrl =
    'https://expense-tracker-backend-47s3.vercel.app/api/v1';

String _resolveBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv.replaceFirst(RegExp(r'/$'), '');

  if (kIsWeb) return _defaultApiBaseUrl;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _defaultApiBaseUrl;
    default:
      return _defaultApiBaseUrl;
  }
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(dio, storage));
  return dio;
});
