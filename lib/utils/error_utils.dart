import 'package:postgrest/postgrest.dart';

/// بيحوّل أي exception (خصوصًا PostgrestException من نداءات RPC) لرسالة
/// تشخيصية حقيقية بدل رسالة عامة — عشان أي خطأ يبان سببه بالظبط في الشاشة.
String describeError(Object e) {
  if (e is PostgrestException) {
    final extra = e.hint ?? e.details?.toString();
    return 'DB error (${e.code ?? '-'}): ${e.message}${extra != null ? ' — $extra' : ''}';
  }
  return e.toString();
}
