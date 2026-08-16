import '../models/chat_message.dart';
import '../models/encounter.dart';
import '../models/patient_summary.dart';
import '../models/staff_profile.dart';
import '../services/chat_service.dart';

/// Minimal fallback data — only used when AppConfig.useMockData is flipped
/// back to true for offline demos. Shapes match the real Postgres RPC
/// responses (see models/) so switching between mock and live mode never
/// requires touching the UI layer.
class MockDataService {
  MockDataService._();
  static final MockDataService instance = MockDataService._();

  StaffProfile mockStaffProfile(String entryCode) {
    return StaffProfile(
      staffId: 'staff-$entryCode',
      name: 'Dr. Sarah Mitchell',
      specialty: 'Emergency Medicine',
      role: 'doctor',
      licenseNumber: 'MD-48291',
      hospitalName: 'Central University Hospital',
      workspaceId: 'ws-hospital-01',
      enabledFeatures: const ['ed_module', 'round_module'],
      subscription: const SubscriptionInfo(
        planName: 'Professional',
        isActive: true,
        enabledFeatures: ['ed_module', 'round_module'],
      ),
    );
  }

  List<Encounter> mockEncounters({
    required String botKey,
    EncounterFilter filter = EncounterFilter.all,
  }) {
    final isEd = botKey == 'ed';
    return [
      Encounter(
        encounterId: isEd ? 'ed-001' : 'rnd-001',
        handle: isEd ? '2847' : '12',
        patientName: isEd ? 'James Wilson' : 'Helen Brooks',
        mrn: 'M000123',
        unit: isEd ? null : 'Ward A',
        attending: 'Dr. Mitchell',
        openDays: isEd ? 0 : 2,
        detail: filter.hasDetail ? const [] : null,
      ),
    ];
  }

  PatientSummary mockPatientSummary(String encounterId) {
    return PatientSummary(
      patient: const PatientInfo(
        id: 'patient-1',
        mrn: 'M000123',
        name: 'James Wilson',
        sex: 'm',
        birthYear: 1968,
        allergies: [],
        chronicConditions: [],
      ),
      encounter: EncounterInfo(
        id: encounterId,
        status: 'active',
        source: 'ed',
        openedAt: DateTime.now().subtract(const Duration(hours: 3)),
        dischargedAt: null,
        unit: null,
        attending: 'Dr. Mitchell',
        handle: '2847',
      ),
      latestVitals: [
        VitalReading(
          metric: 'hr',
          value: 88,
          unit: 'bpm',
          measuredAt: DateTime.now().subtract(const Duration(minutes: 15)),
          eventId: 1,
        ),
      ],
      openOrders: const [],
      activeMedications: const [],
      openCommitments: const [],
      openComplications: const [],
      recentNotes: [
        NoteInfo(kind: 'complaint', body: 'Chest pain, onset 2h ago', at: DateTime.now()),
      ],
      attachments: const [],
    );
  }

  List<VitalSeriesPoint> mockVitalsSeries(String metric, int hours) {
    final now = DateTime.now();
    return List.generate(8, (i) {
      final base = metric.toLowerCase().contains('hr') ? 85.0 : 98.0;
      return VitalSeriesPoint(
        timestamp: now.subtract(Duration(hours: hours - (i * hours ~/ 8))),
        value: base + (i % 3) * 2 - 2,
      );
    });
  }

  WebhookResponse mockWebhookResponse({
    required String type,
    String? text,
    String? caption,
  }) {
    final lower = (text ?? caption ?? '').toLowerCase();

    if (lower.contains('new patient') || lower.contains('admit')) {
      return const WebhookResponse(
        replyText: 'Please review the new patient details before I save them. Save? (ok/edit)',
        attachments: [],
      );
    }

    if (type == 'photo') {
      return const WebhookResponse(
        replyText: 'Photo received. I can see the wound dressing — would you like me to add a note?',
        attachments: [],
      );
    }

    if (type == 'voice') {
      return WebhookResponse(
        replyText: 'Understood. I\'ve noted: "${text ?? 'voice message processed'}". Anything else?',
        attachments: const [],
      );
    }

    return WebhookResponse(
      replyText: text != null && text.isNotEmpty
          ? 'Got it. "${text.length > 60 ? '${text.substring(0, 60)}...' : text}" has been noted.'
          : 'Message received. How can I help with this case?',
      attachments: const [],
    );
  }

  ReviewCardData mockNewPatientReview() {
    return const ReviewCardData(
      title: 'New Patient — Review Before Save',
      fields: {
        'Name': 'James Wilson',
        'Age': '58',
        'Sex': 'Male',
        'Complaint': 'Chest pain, onset 2h ago',
        'Ticket': 'ED-2847',
      },
      confirmAction: 'Confirm & Save Patient',
      rejectAction: 'Cancel',
    );
  }
}
