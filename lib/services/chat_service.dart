import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import 'mock_data_service.dart';

/// Uploads attachments to Supabase Storage and sends messages via n8n webhooks.
class ChatService {
  ChatService({SupabaseClient? client, http.Client? httpClient})
      : _client = client,
        _http = httpClient ?? http.Client();

  final SupabaseClient? _client;
  final http.Client _http;
  final _uuid = const Uuid();

  String _webhookUrl(ChatBotKey botKey) {
    switch (botKey) {
      case ChatBotKey.ed:
        return AppConfig.edWebhookUrl;
      case ChatBotKey.round:
        return AppConfig.roundsWebhookUrl;
      case ChatBotKey.clinic:
        return AppConfig.clinicWebhookUrl;
    }
  }

  Future<String> uploadAttachment({
    required String entryCode,
    required File file,
    required String type,
  }) async {
    if (AppConfig.useMockData || _client == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return 'mock/$entryCode/${_uuid.v4()}${p.extension(file.path)}';
    }

    final ext = p.extension(file.path);
    final storagePath = '$entryCode/${_uuid.v4()}$ext';
    await _client.storage.from(AppConfig.attachmentsBucket).upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: _mimeForExt(ext)),
        );
    return storagePath;
  }

  Future<WebhookResponse> sendMessage({
    required String entryCode,
    required ChatBotKey botKey,
    required String type,
    String? text,
    String? audioStoragePath,
    String? photoStoragePath,
    String? caption,
    // موجودين بس لما الرسالة جاية من جوه كارت مريض معيّن — بيوصّلوا
    // encounter_id صريح للـ workflow عشان الـ AI Agent ميحتاجش يسأل "مين
    // المريض؟" أو يدوّر بالتذكرة؛ المريض أصلًا معروف من كون الطبيب فاتح
    // كارته. غايبين تمامًا من أي رسالة تانية (لو وجدت مستقبلًا).
    String? encounterId,
    String? ticket,
    String? patientName,
  }) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return MockDataService.instance.mockWebhookResponse(
        type: type,
        text: text,
        caption: caption,
      );
    }

    final payload = {
      'chat_id': entryCode,
      'bot_key': botKey.value,
      'type': type,
      if (text != null) 'text': text,
      if (audioStoragePath != null) 'audio_storage_path': audioStoragePath,
      if (photoStoragePath != null) 'photo_storage_path': photoStoragePath,
      if (caption != null) 'caption': caption,
      if (encounterId != null) 'encounter_id': encounterId,
      if (ticket != null) 'ticket': ticket,
      if (patientName != null) 'patient_name': patientName,
    };

    final response = await _http.post(
      Uri.parse(_webhookUrl(botKey)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Webhook failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return WebhookResponse.fromJson(body);
  }

  /// رابط مؤقت (ساعة افتراضيًا) للمرفق — الـ bucket مش عام، فبنستخدم signed
  /// URL بدل getPublicUrl عشان صور المرضى متبقاش قابلة للوصول لأي حد عنده
  /// اللينك على طول. محتاج policy "anon can read attachments" (migration 003).
  Future<String?> getSignedUrl(String storagePath, {int expiresInSeconds = 3600}) async {
    if (AppConfig.useMockData || _client == null) return null;
    try {
      return await _client.storage
          .from(AppConfig.attachmentsBucket)
          .createSignedUrl(storagePath, expiresInSeconds);
    } catch (_) {
      return null;
    }
  }

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}

class WebhookResponse {
  const WebhookResponse({required this.replyText, required this.attachments});

  final String replyText;
  final List<ChatAttachment> attachments;

  factory WebhookResponse.fromJson(Map<String, dynamic> json) {
    return WebhookResponse(
      replyText: json['reply_text']?.toString() ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map(
                (e) => ChatAttachment(
                  storagePath: (e as Map<String, dynamic>)['storage_path']?.toString() ?? '',
                  caption: e['caption']?.toString(),
                ),
              )
              .toList() ??
          [],
    );
  }
}
