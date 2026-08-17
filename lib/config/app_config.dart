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
}
