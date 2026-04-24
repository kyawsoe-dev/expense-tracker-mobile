import 'package:dio/dio.dart';

const offlineGroupIdMapKey = 'offline_group_id_map';

bool isOfflineError(DioException error) {
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
}

String buildLocalId(String prefix) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  return 'local-$prefix-$timestamp';
}

bool isLocalOnlyId(String id) => id.startsWith('local-');
