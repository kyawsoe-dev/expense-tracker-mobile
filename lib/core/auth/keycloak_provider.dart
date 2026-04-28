import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_auth_service.dart';

final firebaseAuthServiceProvider = Provider<SocialAuthService>((ref) {
  return SocialAuthService();
});
