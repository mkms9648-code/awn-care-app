/// Single message in a portal escalation thread — mirrors
/// [app_portal_thread]'s `messages[]` shape exactly: { sender, body, created_at }.
enum PortalMessageSender { patient, ai, doctor }

extension PortalMessageSenderExt on PortalMessageSender {
  String get value {
    switch (this) {
      case PortalMessageSender.patient:
        return 'patient';
      case PortalMessageSender.ai:
        return 'ai';
      case PortalMessageSender.doctor:
        return 'doctor';
    }
  }
}

class PortalMessage {
  const PortalMessage({
    required this.sender,
    required this.body,
    required this.createdAt,
    this.attachmentStoragePath,
    this.attachmentKind,
  });

  final PortalMessageSender sender;
  final String body;
  final DateTime createdAt;
  final String? attachmentStoragePath;
  final String? attachmentKind;

  bool get hasImageAttachment => attachmentStoragePath != null && attachmentKind == 'photo';
  bool get hasDocAttachment => attachmentStoragePath != null && attachmentKind != null && attachmentKind != 'photo';

  factory PortalMessage.fromJson(Map<String, dynamic> json) {
    return PortalMessage(
      sender: PortalMessageSender.values.firstWhere(
        (s) => s.value == json['sender']?.toString(),
        orElse: () => PortalMessageSender.patient,
      ),
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      attachmentStoragePath: json['attachment_storage_path']?.toString(),
      attachmentKind: json['attachment_kind']?.toString(),
    );
  }
}
