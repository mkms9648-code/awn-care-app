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
  });

  final PortalMessageSender sender;
  final String body;
  final DateTime createdAt;

  factory PortalMessage.fromJson(Map<String, dynamic> json) {
    return PortalMessage(
      sender: PortalMessageSender.values.firstWhere(
        (s) => s.value == json['sender']?.toString(),
        orElse: () => PortalMessageSender.patient,
      ),
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}
