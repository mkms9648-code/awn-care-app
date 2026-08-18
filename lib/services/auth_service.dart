import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persists the physician 6-digit entry code securely on device.
class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keyEntryCode = 'awn_care_entry_code';
  static const _keyEntryCodeHistory = 'awn_care_entry_code_history';
  static const _keyDeviceId = 'awn_care_device_id';
  static const _maxHistory = 5;

  Future<String?> getEntryCode() => _storage.read(key: _keyEntryCode);

  /// أكواد سبق نجح الدخول بيها على الجهاز ده، الأحدث أولًا — عشان الشاشة
  /// تقترحها بدل ما الطبيب يفتكر/يدوّر عليها لو استخدم أكتر من كود (مثلاً
  /// جهاز مشترك بين أكتر من دكتور).
  Future<List<String>> getEntryCodeHistory() async {
    final raw = await _storage.read(key: _keyEntryCodeHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntryCode(String code) async {
    await _storage.write(key: _keyEntryCode, value: code);
    final history = await getEntryCodeHistory();
    history.remove(code);
    history.insert(0, code);
    await _storage.write(
      key: _keyEntryCodeHistory,
      value: jsonEncode(history.take(_maxHistory).toList()),
    );
  }

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
