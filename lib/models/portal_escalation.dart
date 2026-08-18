/// Row returned by [app_portal_inbox] — matches the real Postgres function's
/// `results[]` shape exactly: { escalation_id, encounter_id, patient_name,
/// patient_phone, ticket, reason, status, created_at, resolved_at }.
/// `status` is one of 'open' / 'replied' / 'resolved'.
class PortalEscalation {
  const PortalEscalation({
    required this.escalationId,
    required this.encounterId,
    required this.patientName,
    required this.patientPhone,
    required this.ticket,
    required this.botKey,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  final String escalationId;
  final String encounterId;
  final String patientName;
  final String? patientPhone;
  final String? ticket;
  final String botKey;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isOpen => status == 'open';
  bool get isReplied => status == 'replied';
  bool get isResolved => status == 'resolved';

  factory PortalEscalation.fromJson(Map<String, dynamic> json) {
    return PortalEscalation(
      escalationId: json['escalation_id']?.toString() ?? '',
      encounterId: json['encounter_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Unknown',
      patientPhone: json['patient_phone']?.toString(),
      ticket: json['ticket']?.toString(),
      botKey: json['bot_key']?.toString() ?? 'ed',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())?.toLocal()
          : null,
    );
  }
}

/// Result of [app_generate_portal_code] — the plaintext `code` is returned
/// exactly once (stored server-side only as a hash), so this is never
/// persisted anywhere, only shown once in a dialog right after generation.
class PortalCodeResult {
  const PortalCodeResult({
    required this.accessCodeId,
    required this.code,
    required this.codeDisplay,
    required this.patientName,
  });

  final String accessCodeId;
  final String code;
  final String codeDisplay;
  final String patientName;

  factory PortalCodeResult.fromJson(Map<String, dynamic> json) {
    return PortalCodeResult(
      accessCodeId: json['access_code_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      codeDisplay: json['code_display']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
    );
  }
}
