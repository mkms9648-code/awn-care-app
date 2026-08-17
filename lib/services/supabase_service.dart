import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../models/encounter.dart';
import '../models/patient_summary.dart';
import '../models/analytics_summary.dart';
import '../models/staff_profile.dart';
import '../models/unit_info.dart';
import 'mock_data_service.dart';

/// Direct Supabase RPC calls matching existing Postgres function signatures.
class SupabaseService {
  SupabaseService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<StaffProfile> resolveStaff(String entryCode, {String? deviceId}) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return MockDataService.instance.mockStaffProfile(entryCode);
    }
    final result = await _client!.rpc(
      AppConfig.rpcResolveStaff,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': 'ed',
        'p_chat_id': entryCode,
        if (deviceId != null) 'p_device_id': deviceId,
      },
    );
    return StaffProfile.fromJson(result as Map<String, dynamic>);
  }

  /// تسجيل مريض جديد مباشرة من زرار "+" في التاب — اسم وتذكرة بس، وكل حاجة
  /// تانية اختيارية/فاضية. مفيش كارت مراجعة هنا لأن الطبيب هو نفسه اللي كاتب
  /// القيمتين يدويًا (مفيش تفسير AI وسيط ممكن يغلط فيه).
  Future<String> createPatient({
    required String entryCode,
    required String botKey,
    required String name,
    required String ticket,
    String? source,
  }) async {
    if (AppConfig.useMockData || _client == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return 'mock-${DateTime.now().microsecondsSinceEpoch}';
    }
    final result = await _client.rpc(
      AppConfig.rpcCreatePatient,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_ticket': ticket,
        'p_name': name,
        if (source != null) 'p_source': source,
      },
    );
    final map = result as Map<String, dynamic>;
    if (map['status'] != 'ok') {
      switch (map['reason']) {
        case 'ticket_exists':
          throw Exception('Ticket #$ticket is already in use by an active patient.');
        case 'name_required':
          throw Exception('Patient name is required.');
        case 'ticket_required':
          throw Exception('Ticket number is required.');
        default:
          throw Exception('Could not add patient: ${map['reason'] ?? map}');
      }
    }
    return map['encounter_id'].toString();
  }

  Future<List<Encounter>> encounterList({
    required String entryCode,
    required String botKey,
    EncounterFilter filter = EncounterFilter.all,
    DateTime? from,
    DateTime? to,
  }) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return MockDataService.instance.mockEncounters(
        botKey: botKey,
        filter: filter,
      );
    }
    // p_from/p_to are optional (migration 030). Only sent when provided, so
    // boards keep calling the original 5-arg signature unchanged.
    final result = await _client!.rpc(
      AppConfig.rpcEncounterList,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_filter': filter.value,
        'p_category': null,
        if (from != null) 'p_from': from.toUtc().toIso8601String(),
        if (to != null) 'p_to': to.toUtc().toIso8601String(),
      },
    );
    final results = (result as Map<String, dynamic>)['results'] as List<dynamic>? ?? [];
    return results.map((e) => Encounter.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// كل قراءات الفيتالز للزيارة (مش آخر قراءة بس) — تُحمّل بس لما قسم
  /// الفيتالز في كارت المريض يتفتح (lazy load)، عشان الشاشة الافتراضية تفضل
  /// خفيفة.
  Future<List<VitalHistoryReading>> vitalsHistory({
    required String entryCode,
    required String botKey,
    required String encounterId,
  }) async {
    if (AppConfig.useMockData || _client == null) return [];
    final result = await _client.rpc(
      AppConfig.rpcVitalsHistory,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
      },
    );
    final readings = (result as Map<String, dynamic>)['readings'] as List<dynamic>? ?? [];
    return readings.map((e) => VitalHistoryReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// كل الملاحظات للزيارة، اختياري تتفلتر بـ kind — بتغذّي أقسام الهيستوري/
  /// التنبيهات وتعليمات العلاج/خطة العلاج/نتائج التحاليل.
  Future<List<NoteHistoryEntry>> notesHistory({
    required String entryCode,
    required String botKey,
    required String encounterId,
    String? kind,
  }) async {
    if (AppConfig.useMockData || _client == null) return [];
    final result = await _client.rpc(
      AppConfig.rpcNotesHistory,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
        if (kind != null) 'p_kind': kind,
      },
    );
    final notes = (result as Map<String, dynamic>)['notes'] as List<dynamic>? ?? [];
    return notes.map((e) => NoteHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// الروشتة الكاملة (أدوية نشطة ومتوقفة) — مفيدة لو المريض رجع تاني للعيادة.
  Future<List<MedicationHistoryEntry>> medicationsHistory({
    required String entryCode,
    required String botKey,
    required String encounterId,
  }) async {
    if (AppConfig.useMockData || _client == null) return [];
    final result = await _client.rpc(
      AppConfig.rpcMedicationsHistory,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
      },
    );
    final meds = (result as Map<String, dynamic>)['medications'] as List<dynamic>? ?? [];
    return meds.map((e) => MedicationHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PatientSummary> patientSummary({
    required String entryCode,
    required String botKey,
    required String encounterId,
  }) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return MockDataService.instance.mockPatientSummary(encounterId);
    }
    final result = await _client!.rpc(
      AppConfig.rpcPatientSummary,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
      },
    );
    return PatientSummary.fromJson(result as Map<String, dynamic>);
  }

  Future<List<VitalSeriesPoint>> vitalsSeries({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String metric,
    int hours = 24,
  }) async {
    if (AppConfig.useMockData) {
      return MockDataService.instance.mockVitalsSeries(metric, hours);
    }
    final result = await _client!.rpc(
      AppConfig.rpcVitalsSeries,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
        'p_metric': metric,
        'p_hours': hours,
      },
    );
    final points = (result as Map<String, dynamic>)['points'] as List<dynamic>? ?? [];
    return points.map((e) => VitalSeriesPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// تاريخ المحادثة المتخزّن فعليًا في n8n_chat_histories (نفس الذاكرة اللي
  /// الـ AI Agent بيستخدمها) — بدل تخزين محلي جديد على الجهاز.
  Future<List<ChatMessage>> chatHistory({
    required String entryCode,
    required String botKey,
    int limit = 50,
  }) async {
    if (AppConfig.useMockData || _client == null) return [];
    final result = await _client.rpc(
      AppConfig.rpcChatHistory,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_limit': limit,
      },
    );
    return (result as List<dynamic>)
        .map((e) => ChatMessage.fromHistoryRow(e as Map<String, dynamic>))
        .toList();
  }

  /// قائمة الأقسام (units) بتاعة مؤسسة الطبيب — لقائمة "يتحجز في أنهي قسم".
  Future<List<UnitInfo>> listUnits({required String entryCode, required String botKey}) async {
    if (AppConfig.useMockData || _client == null) return [];
    final result = await _client.rpc(
      AppConfig.rpcListUnits,
      params: {'p_platform': AppConfig.platform, 'p_bot_key': botKey, 'p_chat_id': entryCode},
    );
    return (result as List<dynamic>).map((e) => UnitInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// إخراج المريض — زرار مباشر من التطبيق (مش عن طريق الشات)، بيستخدم نفس
  /// بوابة الكتابة العادية (app_ingest_events) بحدث discharge فاضي.
  Future<void> dischargeEncounter({
    required String entryCode,
    required String botKey,
    required String encounterId,
  }) async {
    if (AppConfig.useMockData || _client == null) return;
    final result = await _client.rpc(
      AppConfig.rpcIngestEvents,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_events': [
          {'event_type': 'discharge', 'encounter_id': encounterId, 'payload': {}},
        ],
        'p_dry_run': false,
      },
    );
    final status = (result as Map<String, dynamic>)['status'];
    if (status != 'ok') {
      throw Exception('Discharge failed: ${result['problems'] ?? result}');
    }
  }

  /// نداء عام لمجموعة أحداث عبر app_ingest_events في نداء واحد ذرّي — يا كلهم
  /// يتسجلوا يا محدش. dischargeEncounter/admitToUnit وباقي الإجراءات
  /// "الحتمية والواضحة" (مش محتاجة فهم لغوي) بتستخدمها عشان تتنفذ مباشرة من
  /// التطبيق من غير ما تعدي بالشات.
  Future<void> _ingestEvents({
    required String entryCode,
    required String botKey,
    required List<Map<String, dynamic>> events,
    required String actionLabel,
  }) async {
    if (AppConfig.useMockData || _client == null) return;
    final result = await _client.rpc(
      AppConfig.rpcIngestEvents,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_events': events,
        'p_dry_run': false,
      },
    );
    final status = (result as Map<String, dynamic>)['status'];
    if (status != 'ok') {
      throw Exception('$actionLabel failed: ${result['problems'] ?? result}');
    }
  }

  Future<void> _ingestSingleEvent({
    required String entryCode,
    required String botKey,
    required String eventType,
    required String encounterId,
    required Map<String, dynamic> payload,
    required String actionLabel,
  }) =>
      _ingestEvents(
        entryCode: entryCode,
        botKey: botKey,
        events: [
          {'event_type': eventType, 'encounter_id': encounterId, 'payload': payload},
        ],
        actionLabel: actionLabel,
      );

  /// تنفيذ أوردر (checkbox في كارت المريض).
  Future<void> completeOrder({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String orderId,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'order_completed',
        encounterId: encounterId,
        payload: {'order_id': orderId},
        actionLabel: 'Complete order',
      );

  /// تنفيذ أوردر ومعاه نتيجة التحليل/الأشعة في نفس اللحظة — حدثين في نداء
  /// واحد ذرّي (order_completed + note_added kind='result') عشان النتيجة
  /// تظهر في قسم "نتائج التحاليل/الأشعة" المنفصل عن الطلبات.
  Future<void> completeOrderWithResult({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String orderId,
    required String testName,
    required String result,
  }) =>
      _ingestEvents(
        entryCode: entryCode,
        botKey: botKey,
        events: [
          {'event_type': 'order_completed', 'encounter_id': encounterId, 'payload': {'order_id': orderId}},
          {
            'event_type': 'note_added',
            'encounter_id': encounterId,
            'payload': {'kind': 'result', 'body': '$testName: $result'},
          },
        ],
        actionLabel: 'Complete order',
      );

  /// التراجع عن تنفيذ أوردر (رجّعه pending تاني).
  Future<void> reopenOrder({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String orderId,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'order_reopened',
        encounterId: encounterId,
        payload: {'order_id': orderId},
        actionLabel: 'Reopen order',
      );

  /// مسح/إبطال أوردر (لسه pending أو خلص completed) — بيرجع reopen ممكن.
  Future<void> cancelOrder({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String orderId,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'order_cancelled',
        encounterId: encounterId,
        payload: {'order_id': orderId},
        actionLabel: 'Cancel order',
      );

  /// إضافة أوردر جديد مباشرة من كارت المريض (بدون الشات).
  Future<void> addOrder({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String category,
    required String name,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'order_placed',
        encounterId: encounterId,
        payload: {'category': category, 'name': name},
        actionLabel: 'Add order',
      );

  /// إضافة ملاحظة جديدة (شكوى/تاريخ/فحص/تشخيص) مباشرة من كارت المريض.
  Future<void> addNote({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String kind,
    required String body,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'note_added',
        encounterId: encounterId,
        payload: {'kind': kind, 'body': body},
        actionLabel: 'Add note',
      );

  /// إضافة روشتة/دواء جديد مباشرة من كارت المريض. endsAt اختياري (مدة العلاج).
  Future<void> addPrescription({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String name,
    String? dose,
    String? route,
    String? frequency,
    DateTime? endsAt,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'medication_started',
        encounterId: encounterId,
        payload: {
          'name': name,
          if (dose != null && dose.isNotEmpty) 'dose': dose,
          if (route != null && route.isNotEmpty) 'route': route,
          if (frequency != null && frequency.isNotEmpty) 'frequency': frequency,
          if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        },
        actionLabel: 'Add prescription',
      );

  /// تسجيل موعد متابعة (follow-up) جديد مباشرة من كارت المريض.
  Future<void> addFollowUp({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String text,
    required DateTime dueAt,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'commitment_created',
        encounterId: encounterId,
        payload: {'text': text, 'due_at': dueAt.toUtc().toIso8601String()},
        actionLabel: 'Add follow-up',
      );

  /// تسجيل علامة حيوية (فيتال) جديدة مباشرة من كارت المريض — قايمة قراءات
  /// عشان الضغط بيحتاج قراءتين (bp_sys/bp_dia) في نداء واحد، وأي مقياس تاني
  /// بيبعت قراءة واحدة بس في القايمة.
  Future<void> addVital({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required List<Map<String, dynamic>> readings,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'vitals_recorded',
        encounterId: encounterId,
        payload: {
          'readings': readings,
          'measured_at': DateTime.now().toUtc().toIso8601String(),
        },
        actionLabel: 'Add vital',
      );

  /// تسجيل مضاعفة مفتوحة جديدة مباشرة من كارت المريض.
  Future<void> addComplication({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String description,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'complication_opened',
        encounterId: encounterId,
        payload: {'description': description},
        actionLabel: 'Add complication',
      );

  /// إضافة صورة/مرفق للمريض مباشرة من كارت المريض (بدون الشات). storagePath
  /// جاي من ChatService.uploadAttachment (نفس الرفع المستخدم في الشات).
  Future<void> addAttachment({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required String storagePath,
    String kind = 'image',
    String? caption,
  }) =>
      _ingestSingleEvent(
        entryCode: entryCode,
        botKey: botKey,
        eventType: 'attachment_added',
        encounterId: encounterId,
        payload: {
          'kind': kind,
          'storage_path': storagePath,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        },
        actionLabel: 'Add attachment',
      );

  /// حجز المريض لقسم معيّن — الطبيب بيختار القسم بس، مفيش رقم يتكتب يدويًا.
  /// بينادي app_admit (عشان يعمل الربط الفعلي بين الطوارئ والراوند، بمعرّف
  /// داخلي فريد لكل حجز — تفصيلة routing تقنية بحتة، مش حاجة تظهر للطبيب)،
  /// وبعدين unit_transfer (event موجود أصلًا في القاموس، مش مستخدم من الشات)
  /// عشان current_unit_id يتسجّل صح ويبان في ملخص المريض.
  Future<void> admitToUnit({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required UnitInfo unit,
  }) async {
    if (AppConfig.useMockData || _client == null) return;

    // app_admit بيرفض أي معرّف داخلي متكرر لمريض تاني لسه active — لازم قيمة
    // فريدة لكل حجز، مش اسم القسم لوحده (غير كده تاني مريض في نفس القسم
    // هيترفض). بنلحق جزء من الـ encounter_id عشان يضمن التفرّد. القيمة دي
    // مفيش داعي إن الطبيب يشوفها أو يكتبها أبدًا.
    final unitKey = unit.key.isNotEmpty ? unit.key : unit.name;
    final internalSlot = '$unitKey-${encounterId.substring(0, 8)}';

    final admitResult = await _client.rpc(
      AppConfig.rpcAdmit,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
        'p_bed': internalSlot,
      },
    );
    final admitStatus = (admitResult as Map<String, dynamic>)['status'];
    if (admitStatus != 'ok') {
      throw Exception('Could not admit to ${unit.name}. Please try again.');
    }

    final eventsResult = await _client.rpc(
      AppConfig.rpcIngestEvents,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_events': [
          {
            'event_type': 'unit_transfer',
            'encounter_id': encounterId,
            'payload': {'to_unit_id': unit.id},
          },
        ],
        'p_dry_run': false,
      },
    );
    final eventsStatus = (eventsResult as Map<String, dynamic>)['status'];
    if (eventsStatus != 'ok') {
      throw Exception('Unit assignment failed: ${eventsResult['problems'] ?? eventsResult}');
    }
  }

  /// آخر علامات حيوية "معلّقة" (اتسجّلت بصوت/كتابة لسه محتاجة تأكيد) لنفس
  /// المحادثة — مصدر الحقيقة للكارت القابل للتعديل قبل الحفظ، بدل ما نعتمد
  /// على تفسير نص رد الأجنت. null لو مفيش حاجة معلّقة (خلصت صلاحيتها أو
  /// اتأكدت أصلًا).
  Future<PendingVitals?> latestPendingVitals({
    required String entryCode,
    required String botKey,
  }) async {
    if (AppConfig.useMockData || _client == null) return null;
    final result = await _client.rpc(
      AppConfig.rpcLatestPending,
      params: {'p_platform': AppConfig.platform, 'p_bot_key': botKey, 'p_chat_id': entryCode},
    );
    final map = result as Map<String, dynamic>;
    if (map['status'] != 'found') return null;
    return PendingVitals.fromJson(map);
  }

  /// المرحلة الأولى لتسجيل علامة حيوية — بتتخزّن مؤقتًا لحد التأكيد. بتتنادى
  /// تاني (بتلغي أي pending سابق على نفس المحادثة) لو الطبيب عدّل القيم في
  /// كارت المراجعة قبل ما يأكّد.
  Future<PendingVitals> stageVitals({
    required String entryCode,
    required String botKey,
    required String encounterId,
    required List<Map<String, dynamic>> readings,
    required DateTime measuredAt,
  }) async {
    if (AppConfig.useMockData || _client == null) {
      return PendingVitals(
        pendingId: 'mock',
        encounterId: encounterId,
        readings: readings,
        measuredAt: measuredAt,
      );
    }
    final result = await _client.rpc(
      AppConfig.rpcStageVitals,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_encounter_id': encounterId,
        'p_readings': readings,
        'p_measured_at': measuredAt.toUtc().toIso8601String(),
      },
    );
    final map = result as Map<String, dynamic>;
    if (map['status'] != 'staged') {
      throw Exception('Could not stage vitals: ${map['reason'] ?? map}');
    }
    return PendingVitals(
      pendingId: map['pending_id'].toString(),
      encounterId: encounterId,
      readings: readings,
      measuredAt: measuredAt,
    );
  }

  /// المرحلة الثانية — تأكيد نهائي لعلامة حيوية معلّقة بنفس القيم اللي
  /// اتخزّنت وقت الـ staging. لو الطبيب عدّل حاجة، استخدم [stageVitals] الأول
  /// بالقيم الجديدة ثم أكّد الـ pending_id الجديد.
  Future<void> commitVitals({
    required String entryCode,
    required String botKey,
    required String pendingId,
  }) async {
    if (AppConfig.useMockData || _client == null) return;
    final result = await _client.rpc(
      AppConfig.rpcCommitVitals,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_pending_id': pendingId,
      },
    );
    final map = result as Map<String, dynamic>;
    if (map['status'] != 'ok') {
      throw Exception('Could not confirm vitals: ${map['status']}. Please try again.');
    }
  }

  /// ملخص الأداء الشخصي لتاب التحليلات — حالات الدكتور الحالي بس (مش كل
  /// المؤسسة)، آخر [days] يوم للمؤشرات الزمنية (اتجاه الحالات المفتوحة).
  /// p_scope: 'mine' (بس حالات الطبيب الحالي) أو 'workspace' (المستشفى كله —
  /// بتضيف doctor_workload/active_doctors_count فوق نفس الحقول التانية).
  Future<AnalyticsSummary> analyticsSummary({
    required String entryCode,
    required String botKey,
    int days = 30,
    String scope = 'mine',
  }) async {
    if (AppConfig.useMockData || _client == null) return AnalyticsSummary.empty;
    final result = await _client.rpc(
      AppConfig.rpcAnalyticsSummary,
      params: {
        'p_platform': AppConfig.platform,
        'p_bot_key': botKey,
        'p_chat_id': entryCode,
        'p_days': days,
        'p_scope': scope,
      },
    );
    return AnalyticsSummary.fromJson(result as Map<String, dynamic>);
  }

  /// بتشترك في تغييرات كل الجداول اللي بتأثر على البورد — مش encounters بس،
  /// لأن معظم التحديثات الفعلية (طلب جديد، فيتال، التزام...) بتحصل في جداول
  /// تانية مش في صف الـ encounter نفسه. أي تغيير بيستدعي onChange بس (إشارة
  /// "اعمل reload"، مش دمج البيانات يدويًا).
  static const _watchedTables = [
    'encounters',
    'orders',
    'vitals',
    'commitments',
    'complications',
    'notes',
    'handles',
  ];

  RealtimeChannel? subscribeEncounters({
    required String workspaceId,
    required void Function() onChange,
  }) {
    if (AppConfig.useMockData || _client == null) return null;
    var channel = _client.channel('board:$workspaceId');
    for (final table in _watchedTables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'workspace_id',
          value: workspaceId,
        ),
        callback: (_) => onChange(),
      );
    }
    return channel.subscribe();
  }
}
