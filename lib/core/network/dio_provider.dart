import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_store.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final offlineStoreProvider = Provider<OfflineStore>(
    (ref) => OfflineStore(ref.read(tokenStorageProvider)));

String _resolveBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;

  if (kIsWeb) return 'http://127.0.0.1:3000/api/v1';

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:3000/api/v1';
    default:
      return 'http://127.0.0.1:3000/api/v1';
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
