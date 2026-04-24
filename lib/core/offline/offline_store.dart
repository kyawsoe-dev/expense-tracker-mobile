import 'dart:convert';

import '../storage/token_storage.dart';

class OfflineStore {
  final TokenStorage storage;

  const OfflineStore(this.storage);

  Future<void> writeJson(String key, Object value) async {
    await storage.writeValue(key: key, value: jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final raw = await storage.readValue(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final raw = await storage.readValue(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }

  Future<void> remove(String key) => storage.deleteValue(key);
}
