import 'dart:convert';

class SessionUser {
  final String? email;
  final String? name;

  const SessionUser({
    this.email,
    this.name,
  });

  factory SessionUser.fromAccessToken(String? token) {
    if (token == null || token.isEmpty) {
      return const SessionUser();
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return const SessionUser();
      }

      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final email = data['email'] as String?;
      final rawName = data['name'] as String?;

      return SessionUser(
        email: email,
        name: _displayName(rawName, email),
      );
    } catch (_) {
      return const SessionUser();
    }
  }

  factory SessionUser.fromStoredProfile({
    String? email,
    String? name,
  }) {
    return SessionUser(
      email: email,
      name: _displayName(name, email),
    );
  }

  static String? _displayName(String? rawName, String? email) {
    if (rawName != null && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }

    if (email == null || !email.contains('@')) {
      return null;
    }

    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (local.isEmpty) {
      return null;
    }

    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
