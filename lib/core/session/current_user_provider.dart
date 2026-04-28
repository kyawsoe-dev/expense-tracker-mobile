import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';
import 'session_user.dart';

final currentUserProvider = FutureProvider<SessionUser>((ref) async {
  final storage = ref.read(tokenStorageProvider);
  final token = await storage.readAccessToken();
  return SessionUser.fromAccessToken(token);
});
