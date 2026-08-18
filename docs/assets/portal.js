// ============================================================================
// بوابة متابعة المريض — نداءات مباشرة (fetch خام) لـ PostgREST RPC اللي
// مسموحة لـ anon + نداء webhook n8n للإرسال، زائد التبديل بين شاشة الكود
// وشاشة الشات. محمّل كـ ES module من index.html.
//
// عمدًا **مش بنستخدم مكتبة @supabase/supabase-js** — كانت بتتحمّل من esm.sh
// (CDN خارجي)، وده احتمال فشل إضافي (تحميل المكتبة نفسها، تهيئتها، أي فرق
// في السلوك بين نسخها) مش لازم أصلاً لثلاث نداءات REST بسيطة. fetch مباشر
// لنفس الـ endpoint اللي بيشتغل مضبوط لما بيتعمله اختبار مباشر (curl) —
// أقل اعتمادية ممكنة، وأسهل تشخيص لو فشل حاجة.
// ============================================================================

const cfg = window.APP_CONFIG || {};

if (!cfg.SUPABASE_URL || cfg.SUPABASE_URL.includes("YOUR-PROJECT")) {
  document.addEventListener("DOMContentLoaded", () => {
    document.body.innerHTML =
      '<div class="center-msg">لسه محتاج تعدّل ملف <code>config.js</code> بمفاتيح Supabase بتاعتك.</div>';
  });
  throw new Error("APP_CONFIG not set — edit config.js first.");
}

// نداء RPC مباشر عن طريق PostgREST — بنفس الشكل اللي مؤكد شغال (curl) بالظبط:
// POST /rest/v1/rpc/<fn> مع apikey + Authorization + body JSON بالباراميترات.
async function postgrestRpc(fnName, params) {
  const res = await fetch(`${cfg.SUPABASE_URL}/rest/v1/rpc/${fnName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: cfg.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${cfg.SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(params),
  });

  let body = null;
  try {
    body = await res.json();
  } catch (_) {
    body = null;
  }

  if (!res.ok) {
    const message = (body && (body.message || body.hint)) || `HTTP ${res.status}`;
    return { data: null, error: { message } };
  }

  return { data: body, error: null };
}

const POLL_INTERVAL_MS = 5000;
const CODE_STORAGE_KEY = "awn_portal_code";
const NAME_STORAGE_KEY = "awn_portal_name";

const SENDER_LABELS = {
  doctor: "👨‍⚕️ الدكتور",
};

// ----------------------------------------------------------------------------
// أدوات عامة
// ----------------------------------------------------------------------------

export function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[c]));
}

// بيشيل أي حاجة غير حروف/أرقام (مسافات، شرطات) ويكبّر الحروف — الكود بيتخزن
// كـ hash فمهم نبعت نفس الصيغة اللي السيرفر متوقعها بالظبط.
export function normalizeCode(raw) {
  return String(raw || "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
}

// تنسيق العرض بس (XXXX-XXXX-XX) وقت الكتابة — بيقبل مدخل بمسافات/شرطات أو
// من غيرهم، ودايمًا بيرجّع نسخة متنسّقة للعرض في خانة الإدخال.
export function formatCodeForDisplay(raw) {
  const clean = normalizeCode(raw).slice(0, 10);
  const parts = [clean.slice(0, 4), clean.slice(4, 8), clean.slice(8, 10)].filter(Boolean);
  return parts.join("-");
}

// ----------------------------------------------------------------------------
// نداءات الـ backend — الاتنين RPC المسموحين لـ anon + webhook الإرسال
// ----------------------------------------------------------------------------

const REQUEST_TIMEOUT_MS = 12000;

// بيلف أي promise بمهلة — لو الشبكة/الفايروول واقف الطلب من غير ما يرفضه
// بخطأ صريح (بيفضل معلّق "pending" للأبد)، ده بيفشله بوضوح بدل ما الزرار
// يفضل عالق على "جاري التحقق" من غير أي رسالة.
function withTimeout(promise, ms = REQUEST_TIMEOUT_MS) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error("timeout")), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

// app_portal_verify_code(p_access_code) → { valid, patient_first_name?, encounter_id? }
// بيترجع { valid:false, rateLimited:true } لو AWN_TOO_MANY_ATTEMPTS، أو
// { valid:false, error } لو أي خطأ تاني غير متوقع.
export async function verifyCode(code) {
  let result;
  try {
    result = await withTimeout(
      postgrestRpc("app_portal_verify_code", { p_access_code: code })
    );
  } catch (err) {
    if (err && err.message === "timeout") {
      return {
        valid: false,
        error:
          "الطلب استغرق وقت طويل من غير رد — تأكد من اتصال الإنترنت عندك، أو إن الشبكة/الفايروول مش حاجب الوصول لموقع Supabase.",
      };
    }
    return { valid: false, error: err && err.message ? err.message : String(err) };
  }

  const { data, error } = result;

  if (error) {
    if (String(error.message || "").startsWith("AWN_TOO_MANY_ATTEMPTS")) {
      return { valid: false, rateLimited: true };
    }
    return { valid: false, error: error.message };
  }

  return data || { valid: false };
}

// app_portal_thread_patient(p_access_code) → { patient_first_name, messages }
// بيتحقق من الكود في كل نداء — بيرجّع null لو الكود بقى مش صالح (أو أي خطأ).
export async function fetchThread(code) {
  try {
    const { data, error } = await withTimeout(
      postgrestRpc("app_portal_thread_patient", { p_access_code: code })
    );
    if (error) return null;
    return data;
  } catch (_) {
    return null;
  }
}

// POST مباشر لـ webhook n8n — مش نداء Supabase. بيرجّع { reply_text }.
// مهلة أطول من نداءات Supabase (30 ثانية) لأن ده بيمرّ على AI Agent فعلي.
export async function sendMessage(code, text) {
  const url = cfg.PORTAL_WEBHOOK_URL;
  if (!url || url.includes("PLACEHOLDER")) {
    throw new Error("webhook_not_configured");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  let res;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ access_code: code, text }),
      signal: controller.signal,
    });
  } catch (err) {
    if (err && err.name === "AbortError") {
      throw new Error("انتظرنا رد أكتر من 30 ثانية من غير جواب — تأكد من اتصال الإنترنت وجرب تاني.");
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) throw new Error("webhook_failed");
  return res.json();
}

// رفع ملف مباشر لـ Supabase Storage (bucket "attachments" — نفس الاسم/الأسلوب
// اللي التطبيق بيستخدمه لمرفقات الدكتور، عشان اتساق المسارات). بيرجع
// storage_path (بدون الـ bucket نفسه) لتخزينه في السيرفر.
async function uploadToStorage(file, code) {
  const ext = (file.name && file.name.includes(".")) ? file.name.split(".").pop() : (file.type.split("/")[1] || "bin");
  const path = `${code}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const res = await fetch(`${cfg.SUPABASE_URL}/storage/v1/object/attachments/${path}`, {
    method: "POST",
    headers: {
      apikey: cfg.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${cfg.SUPABASE_ANON_KEY}`,
      "Content-Type": file.type || "application/octet-stream",
    },
    body: file,
  });
  if (!res.ok) throw new Error("upload_failed");
  return path;
}

// رابط مؤقت (ساعة) لعرض مرفق — الـ bucket مش عام. بيتم الكاش عشان الـ polling
// المتكرر مايطلبش رابط جديد لنفس الصورة كل شوية ثواني.
const _signedUrlCache = new Map();
async function getSignedUrl(storagePath) {
  if (_signedUrlCache.has(storagePath)) return _signedUrlCache.get(storagePath);
  const res = await fetch(`${cfg.SUPABASE_URL}/storage/v1/object/sign/attachments/${storagePath}`, {
    method: "POST",
    headers: {
      apikey: cfg.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${cfg.SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ expiresIn: 3600 }),
  });
  if (!res.ok) return null;
  const body = await res.json();
  const url = body.signedURL ? `${cfg.SUPABASE_URL}/storage/v1${body.signedURL}` : null;
  if (url) _signedUrlCache.set(storagePath, url);
  return url;
}

// إرسال مرفق (بعد الرفع) — نفس webhook الرسايل، بنوع مختلف. n8n بيسجله على
// كارت المريض الرسمي مباشرة، مش بس في المحادثة.
export async function sendAttachment(code, storagePath, kind, caption) {
  const url = cfg.PORTAL_WEBHOOK_URL;
  if (!url || url.includes("PLACEHOLDER")) throw new Error("webhook_not_configured");
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ access_code: code, type: "attachment", storage_path: storagePath, kind, caption }),
  });
  if (!res.ok) throw new Error("webhook_failed");
  return res.json();
}

// بولّينج للتريد كل ~5 ثواني، بيوقف تلقائي لما التاب يبقى في الخلفية وبيرجع
// يشتغل (مع تحديث فوري) لما التاب يرجع يبان. بيعيد الرندر بس لو محتوى
// الرسايل اتغيّر فعليًا (مقارنة signature نصية بسيطة).
export function startPolling(code, { onUpdate, onInvalid }) {
  let stopped = false;
  let timer = null;
  let lastSignature = null;

  function signatureOf(thread) {
    if (!thread || !Array.isArray(thread.messages)) return "";
    return thread.messages.map((m) => `${m.sender}|${m.created_at}|${m.body}`).join("\n");
  }

  async function poll() {
    const thread = await fetchThread(code);
    if (stopped) return;

    if (!thread) {
      stop();
      onInvalid();
      return;
    }

    const sig = signatureOf(thread);
    if (sig !== lastSignature) {
      lastSignature = sig;
      onUpdate(thread);
    }
  }

  function scheduleNext() {
    if (stopped) return;
    timer = setTimeout(tick, POLL_INTERVAL_MS);
  }

  async function tick() {
    timer = null;
    if (stopped || document.hidden) return; // متوقف طول ما التاب مخفي
    await poll();
    scheduleNext();
  }

  function handleVisibility() {
    if (stopped) return;
    if (!document.hidden && !timer) {
      tick(); // التاب رجع يبان — حدّث فورًا وكمّل الجدولة العادية
    }
  }

  document.addEventListener("visibilitychange", handleVisibility);

  function stop() {
    if (stopped) return;
    stopped = true;
    if (timer) clearTimeout(timer);
    document.removeEventListener("visibilitychange", handleVisibility);
  }

  tick(); // أول تحديث فورًا من غير ما نستنى 5 ثواني

  return {
    stop,
    // نداء فوري خارج الجدول العادي (بعد إرسال رسالة مثلًا)
    pollNow() {
      if (stopped) return;
      if (timer) clearTimeout(timer);
      tick();
    },
  };
}

// ----------------------------------------------------------------------------
// ربط الـ DOM — التبديل بين شاشة الكود وشاشة الشات
// ----------------------------------------------------------------------------

const gateScreen = document.getElementById("gate-screen");
const chatScreen = document.getElementById("chat-screen");
const codeForm = document.getElementById("code-form");
const codeInput = document.getElementById("code-input");
const codeSubmitBtn = document.getElementById("code-submit-btn");
const gateError = document.getElementById("gate-error");
const chatGreeting = document.getElementById("chat-greeting");
const chatMessages = document.getElementById("chat-messages");
const sendForm = document.getElementById("send-form");
const messageInput = document.getElementById("message-input");
const sendBtn = document.getElementById("send-btn");
const micBtn = document.getElementById("mic-btn");
const attachBtn = document.getElementById("attach-btn");
const attachInput = document.getElementById("attach-input");

let activeCode = null;
let pollController = null;

function showGate() {
  chatScreen.hidden = true;
  gateScreen.hidden = false;
}

function showChat() {
  gateScreen.hidden = true;
  chatScreen.hidden = false;
}

function setGateError(msg) {
  gateError.textContent = msg || "";
}

function setGateLoading(loading) {
  codeSubmitBtn.disabled = loading;
  codeSubmitBtn.textContent = loading ? "جاري التحقق…" : "دخول";
}

function renderMessages(thread) {
  const messages = (thread && thread.messages) || [];

  if (messages.length === 0) {
    chatMessages.innerHTML = '<div class="empty-state">مفيش رسايل لسه — اكتب أول رسالة تحت 👇</div>';
    return;
  }

  chatMessages.innerHTML = messages
    .map((m, i) => {
      const side = m.sender === "patient" ? "bubble-patient" : m.sender === "doctor" ? "bubble-doctor" : "bubble-ai";
      const label = SENDER_LABELS[m.sender] ? `<div class="bubble-label">${SENDER_LABELS[m.sender]}</div>` : "";
      const isImage = m.attachment_storage_path && m.attachment_kind === "photo";
      const isDoc = m.attachment_storage_path && m.attachment_kind !== "photo";
      const attachmentHtml = isImage
        ? `<div class="bubble-attachment" data-path="${escapeHtml(m.attachment_storage_path)}" data-idx="${i}"><div class="attachment-loading">جاري تحميل الصورة…</div></div>`
        : isDoc
        ? `<div class="bubble-attachment-doc" data-path="${escapeHtml(m.attachment_storage_path)}" data-idx="${i}"><i class="ti ti-file-text"></i> فتح المستند</div>`
        : "";
      return `
        <div class="bubble ${side}">
          ${label}
          ${attachmentHtml}
          <div class="bubble-text" dir="auto">${escapeHtml(m.body)}</div>
        </div>`;
    })
    .join("");

  chatMessages.scrollTop = chatMessages.scrollHeight;

  // تحميل روابط الصور/المستندات الموقّعة بعد الرندر (async، مش هيوقف عرض النص)
  chatMessages.querySelectorAll(".bubble-attachment[data-path]").forEach((el) => {
    getSignedUrl(el.dataset.path).then((url) => {
      el.innerHTML = url
        ? `<img src="${escapeHtml(url)}" alt="مرفق" loading="lazy" />`
        : '<div class="attachment-loading">تعذّر تحميل الصورة</div>';
    });
  });
  chatMessages.querySelectorAll(".bubble-attachment-doc[data-path]").forEach((el) => {
    el.addEventListener("click", async () => {
      const url = await getSignedUrl(el.dataset.path);
      if (url) window.open(url, "_blank");
    });
  });
}

function backToGate(message) {
  if (pollController) {
    pollController.stop();
    pollController = null;
  }
  sessionStorage.removeItem(CODE_STORAGE_KEY);
  sessionStorage.removeItem(NAME_STORAGE_KEY);
  activeCode = null;
  showGate();
  setGateError(message || "");
  setGateLoading(false);
}

function enterChat(code, firstName) {
  activeCode = code;
  sessionStorage.setItem(CODE_STORAGE_KEY, code);
  if (firstName) sessionStorage.setItem(NAME_STORAGE_KEY, firstName);

  chatGreeting.textContent = firstName ? `أهلاً يا ${firstName} 👋` : "أهلاً 👋";
  chatMessages.innerHTML = '<p class="muted" style="padding:16px;">جاري التحميل…</p>';
  showChat();

  if (pollController) pollController.stop();
  pollController = startPolling(code, {
    onUpdate: (thread) => {
      if (thread.patient_first_name) {
        chatGreeting.textContent = `أهلاً يا ${thread.patient_first_name} 👋`;
        sessionStorage.setItem(NAME_STORAGE_KEY, thread.patient_first_name);
      }
      renderMessages(thread);
    },
    onInvalid: () => {
      backToGate("انتهت صلاحية الجلسة أو الكود بقى مش صالح. جرّب تدخل الكود تاني.");
    },
  });
}

async function submitCode(rawCode) {
  const code = normalizeCode(rawCode);
  if (!code) {
    setGateError("اكتب الكود الأول.");
    return;
  }

  setGateError("");
  setGateLoading(true);

  try {
    const result = await verifyCode(code);

    if (result.rateLimited) {
      setGateError("محاولات كتير في وقت قصير — استنى شوية وجرب تاني.");
      return;
    }

    if (!result.valid) {
      // result.error موجودة بس في حالة خطأ شبكة/سيرفر (مش "كود غلط" عادي) —
      // مهم نفرّق بينهم عشان مايتوهوش المريض يفكر إنه غلط في كتابة الكود.
      setGateError(result.error || "الكود مش صحيح. تأكد إنك كتبته زي ما هو مكتوب بالظبط.");
      return;
    }

    enterChat(code, result.patient_first_name);
  } catch (err) {
    // أي خطأ غير متوقع (شبكة/تحميل) — لازم يبان بدل ما الزرار يفضل معلّق
    // على "جاري التحقق" للأبد من غير أي رد فعل ظاهر للمريض.
    setGateError("حصل خطأ غير متوقع، جرب تاني كمان شوية. (" + (err && err.message ? err.message : String(err)) + ")");
  } finally {
    setGateLoading(false);
  }
}

codeInput.addEventListener("input", () => {
  const atEnd = codeInput.selectionStart === codeInput.value.length;
  codeInput.value = formatCodeForDisplay(codeInput.value);
  if (atEnd) {
    codeInput.selectionStart = codeInput.selectionEnd = codeInput.value.length;
  }
});

codeForm.addEventListener("submit", (e) => {
  e.preventDefault();
  submitCode(codeInput.value);
});

sendForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const text = messageInput.value.trim();
  if (!text || !activeCode) return;

  messageInput.value = "";
  messageInput.disabled = true;
  sendBtn.disabled = true;

  try {
    await sendMessage(activeCode, text);
    // منستخدمش reply_text يدوي — بنعمل poll فوري فبيتعرض من نفس المصدر
    // (portal_messages) زي رسالة المريض نفسها، من غير تكرار.
    if (pollController) pollController.pollNow();
  } catch (err) {
    const msg = err && err.message && err.message !== "webhook_failed" && err.message !== "webhook_not_configured"
      ? err.message
      : "تعذّر إرسال الرسالة، جرّب تاني.";
    chatMessages.insertAdjacentHTML(
      "beforeend",
      `<div class="send-error">${escapeHtml(msg)}</div>`
    );
    chatMessages.scrollTop = chatMessages.scrollHeight;
  } finally {
    messageInput.disabled = false;
    sendBtn.disabled = false;
    messageInput.focus();
  }
});

// ----------------------------------------------------------------------------
// فويس نوت — عن طريق Web Speech API (تحويل كلام لنص جوه المتصفح نفسه، من
// غير أي رفع صوت أو تعديل في n8n) — بيتحط النص في خانة الكتابة زي ما هو
// ونفس مسار الإرسال العادي بيشتغل عليه. مدعومة في Chrome/Edge بس، فبنخفي
// الزرار تمامًا لو المتصفح مش داعمها بدل ما نعرض حاجة هتفشل.
// ----------------------------------------------------------------------------
const SpeechRecognitionImpl = window.SpeechRecognition || window.webkitSpeechRecognition;
let recognizer = null;
let isRecording = false;

if (SpeechRecognitionImpl && micBtn) {
  micBtn.hidden = false;
  recognizer = new SpeechRecognitionImpl();
  recognizer.lang = "ar-EG";
  recognizer.interimResults = false;
  recognizer.maxAlternatives = 1;

  recognizer.onresult = (event) => {
    const transcript = event.results[0][0].transcript;
    messageInput.value = messageInput.value ? `${messageInput.value} ${transcript}` : transcript;
  };
  recognizer.onerror = () => {
    isRecording = false;
    micBtn.classList.remove("recording");
  };
  recognizer.onend = () => {
    isRecording = false;
    micBtn.classList.remove("recording");
  };

  micBtn.addEventListener("click", () => {
    if (isRecording) {
      recognizer.stop();
      return;
    }
    isRecording = true;
    micBtn.classList.add("recording");
    try {
      recognizer.start();
    } catch (_) {
      isRecording = false;
      micBtn.classList.remove("recording");
    }
  });
} else if (micBtn) {
  micBtn.hidden = true;
}

// ----------------------------------------------------------------------------
// إرفاق صورة/مستند — رفع لـ Storage ثم تسجيله عن طريق webhook n8n (بيتحط على
// كارت المريض تلقائي من جوه الدالة نفسها في السيرفر).
// ----------------------------------------------------------------------------
if (attachBtn && attachInput) {
  attachBtn.addEventListener("click", () => attachInput.click());

  attachInput.addEventListener("change", async () => {
    const file = attachInput.files && attachInput.files[0];
    attachInput.value = ""; // يسمح باختيار نفس الملف تاني لو احتاج
    if (!file || !activeCode) return;

    const MAX_BYTES = 15 * 1024 * 1024;
    if (file.size > MAX_BYTES) {
      chatMessages.insertAdjacentHTML(
        "beforeend",
        '<div class="send-error">الملف كبير أكتر من اللازم (الحد الأقصى 15 ميجا).</div>'
      );
      chatMessages.scrollTop = chatMessages.scrollHeight;
      return;
    }

    const kind = file.type.startsWith("image/") ? "photo" : "document";
    attachBtn.disabled = true;
    try {
      const path = await uploadToStorage(file, activeCode);
      await sendAttachment(activeCode, path, kind, file.name);
      if (pollController) pollController.pollNow();
    } catch (_) {
      chatMessages.insertAdjacentHTML(
        "beforeend",
        '<div class="send-error">تعذّر رفع الملف، جرّب تاني.</div>'
      );
      chatMessages.scrollTop = chatMessages.scrollHeight;
    } finally {
      attachBtn.disabled = false;
    }
  });
}

// ----------------------------------------------------------------------------
// نقطة البداية — QR code (?code=...) أو كود محفوظ من الجلسة الحالية أو شاشة فاضية
// ----------------------------------------------------------------------------

function init() {
  const params = new URLSearchParams(location.search);
  const urlCode = params.get("code");

  if (urlCode) {
    // بنشيل الكود من شريط العنوان فورًا — ميفضلش قاعد في الـ history/referrer.
    const cleanUrl = location.pathname + location.hash;
    history.replaceState({}, document.title, cleanUrl);

    codeInput.value = formatCodeForDisplay(urlCode);
    showGate();
    submitCode(urlCode); // إرسال تلقائي — زي ما لو المريض دخل الكود بنفسه وداس دخول
    return;
  }

  const storedCode = sessionStorage.getItem(CODE_STORAGE_KEY);
  if (storedCode) {
    // كود محفوظ من نفس الجلسة — روح على الشات على طول من غير ما تسأل تاني.
    enterChat(storedCode, sessionStorage.getItem(NAME_STORAGE_KEY));
    return;
  }

  showGate();
}

try {
  init();
} catch (err) {
  setGateError("حصل خطأ أثناء تحميل الصفحة، جرب تحدّث الصفحة. (" + (err && err.message ? err.message : String(err)) + ")");
}
