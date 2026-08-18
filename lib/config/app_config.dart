/// Central configuration for Awn Care backend integration.
///
/// Set [useMockData] to `false` and provide real credentials before production.
class AppConfig {
  AppConfig._();

  static const String appName = 'Awn Care';
  static const String platform = 'mobile';

  /// Toggle mock data for local development without a live backend.
  static const bool useMockData = false;

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kaqoozpuvdvernvlmqbk.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_eDVjcLea7223PDB1seW-kQ_s0K5P-fP',
  );

  static const String edWebhookUrl = String.fromEnvironment(
    'ED_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/ed-mobile',
  );

  static const String roundsWebhookUrl = String.fromEnvironment(
    'ROUNDS_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/round-mobile',
  );

  static const String clinicWebhookUrl = String.fromEnvironment(
    'CLINIC_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/clinic-mobile',
  );

  /// نص عربي حقيقي (مش قاموس ثابت) للتعليمات وسطر جرعة/طريقة الدواء في
  /// الروشتة — stateless، مفيش أدوات ولا وصول لبيانات مريض في الـ workflow ده.
  static const String translateWebhookUrl = String.fromEnvironment(
    'TRANSLATE_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/translate-mobile',
  );

  /// نفس فكرة translateWebhookUrl بس بيرجّع نص منقول من صوت — stateless برضه،
  /// بياخد storage_path لملف مرفوع بالفعل ويرجّع transcribed_text.
  static const String transcribeWebhookUrl = String.fromEnvironment(
    'TRANSCRIBE_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/transcribe-mobile',
  );

  /// صفحة شات بوابة المريض العامة (GitHub Pages) — بيتحط الكود بعدها كـ
  /// query param (?code=...) عشان الـ QR يودّي المريض للشات مباشرة.
  static const String portalBaseUrl = String.fromEnvironment(
    'PORTAL_BASE_URL',
    defaultValue: 'https://www.awnagent.com/care/patient/',
  );

  /// نفس ويب-هوك إرسال الإشعارات اللي لوحة التحكم بتستخدمه — بياخد
  /// {push_tokens[], title, body}. بيُستخدم هنا لما الدكتور يعيّن مهمة لممرض/ة
  /// مباشرة (بدون n8n وسيط، مفيش خطوة AI في المسار ده أصلًا).
  static const String pushWebhookUrl = String.fromEnvironment(
    'PUSH_WEBHOOK_URL',
    defaultValue: 'https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/send-notification-push',
  );

  static const String attachmentsBucket = 'attachments';

  /// RPC function names — must match existing Postgres functions exactly.
  static const String rpcResolveStaff = 'app_resolve_staff';
  static const String rpcEncounterList = 'app_encounter_list';
  static const String rpcPatientSummary = 'app_patient_summary';
  static const String rpcVitalsSeries = 'app_vitals_series';
  static const String rpcChatHistory = 'app_chat_history';
  static const String rpcListUnits = 'app_list_units';
  static const String rpcAdmit = 'app_admit';
  static const String rpcIngestEvents = 'app_ingest_events';
  static const String rpcAnalyticsSummary = 'app_analytics_summary';
  static const String rpcCreatePatient = 'app_create_patient';
  static const String rpcStageVitals = 'app_stage_vitals';
  static const String rpcCommitVitals = 'app_commit_vitals';
  static const String rpcLatestPending = 'app_latest_pending';
  static const String rpcVitalsHistory = 'app_vitals_history';
  static const String rpcNotesHistory = 'app_notes_history';
  static const String rpcMedicationsHistory = 'app_medications_history';
  static const String rpcCorrectEvent = 'app_correct_event';

  /// بوابة المريض (portal) — الكود اللي المريض بيدخل بيه شات المتابعة العام
  /// بعد الزيارة، وصندوق وارد الحالات اللي الـ AI صعّدها للطبيب.
  static const String rpcGeneratePortalCode = 'app_generate_portal_code';
  static const String rpcGetOrCreatePortalCode = 'app_get_or_create_portal_code';
  static const String rpcRevokePortalCode = 'app_revoke_portal_code';
  static const String rpcPortalInbox = 'app_portal_inbox';
  static const String rpcPortalThread = 'app_portal_thread';
  static const String rpcPortalReply = 'app_portal_reply';
  static const String rpcPortalReplyAttachment = 'app_portal_reply_attachment';
  static const String rpcSetPortalAiPaused = 'app_portal_set_ai_paused';
  static const String rpcPortalResolve = 'app_portal_resolve';
  static const String rpcRegisterPushToken = 'app_register_push_token';
  static const String rpcPlanUsage = 'app_plan_usage';
  static const String rpcNotificationsList = 'app_notifications_list';
  static const String rpcNotificationsMarkRead = 'app_notifications_mark_read';
  static const String rpcNurseTaskList = 'app_nurse_task_list';
  static const String rpcNurseTaskAccept = 'app_nurse_task_accept';
  static const String rpcNurseTaskStart = 'app_nurse_task_start';
  static const String rpcNurseTaskComplete = 'app_nurse_task_complete';
  static const String rpcAssignOrderTask = 'app_assign_order_task';
  static const String rpcListNurses = 'app_list_nurses';
}
