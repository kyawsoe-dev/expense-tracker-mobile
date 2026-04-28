import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'keycloak_service.dart';

final keycloakServiceProvider = Provider<KeycloakService>((ref) {
  return KeycloakService();
});
