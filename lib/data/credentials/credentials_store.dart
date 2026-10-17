import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 敏感凭证存储
///
/// 存储位置：`flutter_secure_storage`，设备本地加密存储，
/// 在桌面环境如 Keychain 受限时无缝自动兜底至本地偏好存储，确保 Key 永远不丢失。
class SecretStore {
  final FlutterSecureStorage _storage;

  SecretStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const _keyAiApiKey = 'ai_api_key';

  // ------------------------------------------------------------------
  // AI API Key
  // ------------------------------------------------------------------

  Future<String?> loadAiApiKey() async {
    try {
      final key = await _storage.read(key: _keyAiApiKey);
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_keyAiApiKey);
      return (key == null || key.trim().isEmpty) ? null : key.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAiApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clearAiApiKey();
      return;
    }

    try {
      await _storage.write(key: _keyAiApiKey, value: trimmed);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAiApiKey, trimmed);
    } catch (_) {}
  }

  Future<void> clearAiApiKey() async {
    try {
      await _storage.delete(key: _keyAiApiKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAiApiKey);
    } catch (_) {}
  }

  Future<bool> hasAiApiKey() async => (await loadAiApiKey()) != null;

  /// 脱敏展示，如 `sk-4••••f4`
  static String maskKey(String key) {
    final k = key.trim();
    if (k.length <= 8) return '••••••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 2)}';
  }
}
