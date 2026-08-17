import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// ترجمة نصوص قصيرة (تعليمات/جرعة دواء) للعربي عن طريق n8n — نص حر حقيقي
/// (Gemini)، مش قاموس ثابت، عشان جمل زي "one tablet as needed for headache,
/// maximum 3 tablets daily" لازم تتترجم صح مش تفضل زي ما هي.
class TranslationService {
  TranslationService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// بترجع النص الأصلي زي ما هو لو حصل أي خطأ (شبكة/سيرفر) بدل ما توقف
  /// تصدير الروشتة كلها بسبب فقرة واحدة — مع علم [ok] يوضح هل نجحت فعلًا.
  Future<TranslationResult> translateToArabic(String text) async {
    if (text.trim().isEmpty) return TranslationResult(text: text, ok: true);
    try {
      final response = await _http
          .post(
            Uri.parse(AppConfig.translateWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TranslationResult(text: text, ok: false);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = body['translated_text']?.toString().trim() ?? '';
      if (translated.isEmpty) return TranslationResult(text: text, ok: false);
      return TranslationResult(text: translated, ok: true);
    } catch (_) {
      return TranslationResult(text: text, ok: false);
    }
  }
}

class TranslationResult {
  const TranslationResult({required this.text, required this.ok});
  final String text;
  final bool ok;
}
