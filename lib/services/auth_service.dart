import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persists the physician 6-digit entry code securely on device.
class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keyEntryCode = 'awn_care_entry_code';
  static const _keyDeviceId = 'awn_care_device_id';

  Future<String?> getEntryCode() => _storage.read(key: _keyEntryCode);

  Future<void> saveEntryCode(String code) =>
      _storage.write(key: _keyEntryCode, value: code);

  Future<void> clearEntryCode() => _storage.delete(key: _keyEntryCode);

  Future<bool> isLoggedIn() async {
    final code = await getEntryCode();
    return code != null && code.length == 6;
  }

  /// معرّف عشوائي ثابت لكل تنصيب للتطبيق — بيتولّد مرة واحدة بس ويتخزن، وبيفضل
  /// موجود حتى بعد تسجيل الخروج (مش مرتبط بالكود، مرتبط بالجهاز نفسه). بيتبعت
  /// مع كل محاولة دخول عشان نمنع نفس الكود يشتغل من أكتر من جهاز في نفس الوقت.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await _storage.write(key: _keyDeviceId, value: fresh);
    return fresh;
  }
}
