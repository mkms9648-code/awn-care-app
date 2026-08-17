// إعدادات بوابة المريض — عدّل القيم دي بعد الرفع على الدومين ونشر workflow
// الـ n8n بتاع الشات، مفيش أي حاجة تانية محتاجة تتعدّل في باقي الملفات.
// ============================================================================
window.APP_CONFIG = {
  // من Supabase Dashboard → Project Settings → API (نفس المشروع بتاع باقي
  // النظام — الـ anon key ده عمومًا public وده طبيعي، الحماية الفعلية جوه
  // الدوال نفسها).
  SUPABASE_URL: "https://kaqoozpuvdvernvlmqbk.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_eDVjcLea7223PDB1seW-kQ_s0K5P-fP",

  // رابط webhook بتاع n8n اللي بيستقبل رسايل المريض ويرجّع رد الـ AI.
  // ده مبني على نفس N8N_BASE_URL بتاع admin-dashboard + مسار الـ webhook
  // المحدد في "Patient Portal - n8n Workflow.json" (portal-patient) — يشتغل
  // أوتوماتيك بمجرد ما تستورد الـ workflow ده في n8n وتعمله Activate، من غير
  // ما تحتاج تعدّل هنا تاني.
  PORTAL_WEBHOOK_URL: "https://n8n-c1bz.srv1841520.hstgr.cloud/webhook/portal-patient",
};
