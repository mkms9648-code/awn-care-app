import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';

/// هيستوري شات كل مريض محفوظ محليًا على الجهاز — زي تيليجرام: لو الدكتور
/// قفل التطبيق أو خرج من الكارت ورجعله تاني، الرسايل القديمة (بتاريخها
/// ووقتها) لسه موجودة. مخزّن في Application Documents (مش temp) عشان
/// يعيش بين تشغيلات التطبيق، ملف JSON واحد لكل encounter_id.
class ChatHistoryStore {
  ChatHistoryStore._();

  static const _maxMessagesPerPatient = 300;

  static Future<Directory> _historyDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/chat_history');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fileFor(String encounterId) async {
    final dir = await _historyDir();
    final safe = encounterId.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return File('${dir.path}/$safe.json');
  }

  static Future<List<ChatMessage>> load(String encounterId) async {
    try {
      final file = await _fileFor(encounterId);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // ملف تالف/قديم الشكل — منعرضش كراش، نبدأ هيستوري فاضي بدل ما نوقف الشات.
      return [];
    }
  }

  /// system messages (ترحيب/إشعارات محلية) عمدًا مش بتتحفظ — مفيش قيمة
  /// طبية فيها وهتتكرر لوحدها في كل مرة نفتح الشات لو القائمة فاضية.
  static Future<void> save(String encounterId, List<ChatMessage> messages) async {
    try {
      final persisted = messages.where((m) => m.type != ChatMessageType.system).toList();
      final trimmed =
          persisted.length > _maxMessagesPerPatient
              ? persisted.sublist(persisted.length - _maxMessagesPerPatient)
              : persisted;
      final file = await _fileFor(encounterId);
      await file.writeAsString(jsonEncode(trimmed.map((m) => m.toJson()).toList()));
    } catch (_) {
      // فشل حفظ محلي مش لازم يبوّظ تجربة الشات نفسها.
    }
  }
}
