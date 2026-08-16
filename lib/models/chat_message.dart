import 'dart:convert';

import 'patient_summary.dart';

/// Chat thread message — user, assistant, or review card.
enum ChatMessageType { text, voice, photo, reviewCard, system }

enum ChatMessageStatus { sending, sent, failed, pendingReview }

enum ChatBotKey { ed, round, clinic }

extension ChatBotKeyExt on ChatBotKey {
  String get value {
    switch (this) {
      case ChatBotKey.ed:
        return 'ed';
      case ChatBotKey.round:
        return 'round';
      case ChatBotKey.clinic:
        return 'clinic';
    }
  }

  String get label {
    switch (this) {
      case ChatBotKey.ed:
        return 'ED';
      case ChatBotKey.round:
        return 'Rounds';
      case ChatBotKey.clinic:
        return 'Clinic';
    }
  }
}

class ChatAttachment {
  const ChatAttachment({required this.storagePath, this.caption, this.localPath});

  final String storagePath;
  final String? caption;
  final String? localPath;
}

/// Review card shown before saving a new patient or confirming vitals.
class ReviewCardData {
  const ReviewCardData({
    required this.title,
    required this.fields,
    required this.confirmAction,
    required this.rejectAction,
    this.isConfirmed,
  });

  final String title;
  final Map<String, String> fields;
  final String confirmAction;
  final String rejectAction;
  final bool? isConfirmed;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.isFromUser,
    required this.type,
    this.text,
    List<ChatAttachment>? attachments,
    this.reviewCard,
    this.pendingVitals,
    this.status = ChatMessageStatus.sent,
    DateTime? createdAt,
    this.audioStoragePath,
    this.audioDuration,
  })  : attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final bool isFromUser;
  final ChatMessageType type;
  final String? text;
  List<ChatAttachment> attachments;
  ReviewCardData? reviewCard;
  /// Set only when [reviewCard] is a vitals confirmation — carries the real
  /// staged reading so confirm/reject can act on the DB source of truth
  /// instead of re-parsing the display fields.
  PendingVitals? pendingVitals;
  ChatMessageStatus status;
  final DateTime createdAt;
  String? audioStoragePath;
  Duration? audioDuration;

  bool get isReviewCard => type == ChatMessageType.reviewCard;
  bool get isPendingReview => status == ChatMessageStatus.pendingReview;

  /// بيبني رسالة من صف n8n_chat_histories: { id, message: { type, content } }.
  /// رد الـ Rounds agent بيتخزن كـ JSON خام (echo/ask/...) — بنحاول نستخرج
  /// echo لعرضه، ولو فشل (زي رد Dash النصي العادي) بنعرض المحتوى زي ما هو.
  factory ChatMessage.fromHistoryRow(Map<String, dynamic> row) {
    final msg = row['message'] as Map<String, dynamic>? ?? {};
    final isHuman = msg['type']?.toString() == 'human';
    var content = msg['content']?.toString() ?? '';

    if (isHuman) {
      content = _stripPromptMetadata(content);
    } else {
      content = extractDisplayText(content);
    }

    return ChatMessage(
      id: 'hist-${row['id']}',
      isFromUser: isHuman,
      type: ChatMessageType.text,
      text: content,
      status: ChatMessageStatus.sent,
    );
  }

  /// الرد الحقيقي من الـ Round bot عبارة عن JSON خام {patients, committed,
  /// ask, echo, ...} — دي نفس المنطق اللي fromHistoryRow بيستخدمه لرسايل
  /// الهيستوري القديمة، مفكوك هنا عشان ChatProvider يستخدمه برضو على ردود
  /// الـ webhook الحيّة (كانت قبل كده بتتعرض كـ JSON خام من غير تفكيك — نفس
  /// الرسالة، نفس المنطق، مكان واحد بس). لو المحتوى مش JSON (رد Dash النصي
  /// العادي)، بيرجّعه زي ما هو من غير تغيير.
  static String extractDisplayText(String rawContent) {
    final cleaned = rawContent.replaceAll(RegExp(r'^```(?:json)?\s*|```\s*$'), '').trim();
    try {
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final echo = parsed['echo']?.toString();
      final ask = parsed['ask']?.toString();
      if (echo != null) {
        return ask != null && ask.isNotEmpty ? '$echo\n\n❓ $ask' : echo;
      }
    } catch (_) {
      // مش JSON — سيب المحتوى زي ما هو (حالة Dash النصية العادية)
    }
    return rawContent;
  }

  /// n8n بيحقن سطور تعريفية (التاريخ، Staff ID، Workspace ID، ...) قبل رسالة
  /// الدكتور الحقيقية عشان الـ AI Agent يفهم السياق — مش حاجة يشوفها الدكتور
  /// في تاريخ محادثته. بنشيلها ونسيب رسالته الفعلية بس.
  static final _promptMetadataPattern = RegExp(
    r'^Current date and time[^\n]*\n'
    r'(?:(?:Staff ID|Workspace ID|Chat ID|Source):[^\n]*\n)*'
    r'\n?'
    r'(?:رسالة الدكتور:[ \t]*\n?)?',
  );

  static String _stripPromptMetadata(String content) {
    final match = _promptMetadataPattern.firstMatch(content);
    if (match != null && match.end <= content.length) {
      final rest = content.substring(match.end).trim();
      if (rest.isNotEmpty) return rest;
    }
    return content.trim();
  }
}
