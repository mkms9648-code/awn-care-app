/// متابعة مجدولة من [app_calendar_followups] — عبر كل مرضى الدكتور، مش زيارة
/// واحدة بس زي [Commitment] العادية على كارت المريض.
class CalendarFollowUp {
  const CalendarFollowUp({
    required this.commitmentId,
    required this.encounterId,
    required this.patientName,
    required this.handle,
    required this.text,
    required this.dueAt,
    required this.isOverdue,
  });

  final String commitmentId;
  final String encounterId;
  final String patientName;
  final String? handle;
  final String text;
  final DateTime dueAt;
  final bool isOverdue;

  factory CalendarFollowUp.fromJson(Map<String, dynamic> json) {
    return CalendarFollowUp(
      commitmentId: json['commitment_id']?.toString() ?? '',
      encounterId: json['encounter_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
      handle: json['handle']?.toString(),
      text: json['text']?.toString() ?? '',
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      isOverdue: json['is_overdue'] == true,
    );
  }
}
