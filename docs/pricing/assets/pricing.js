// أسعار عون كير — بيانات الأسعار (مصر فقط) والترجمة + منطق العرض. نسخة ثابتة
// (بدون build tool)، نفس البيانات المستخدمة في نسخة معاينة التصميم.

const PRICING = {
  currency: "egp", clinic: 999, emergency: 1499, inpatient: 1499, pro: 2999, followup: 499, team5: 8999, team10: 14999, hospital: 29999,
};

const TXT = {
  ar: {
    nav: { app: "التطبيق", products: "المنتجات", pricing: "الأسعار", contact: "تواصل معنا", cta: "تجربة التطبيق" },
    hero: { titleAccent: "خطط", titleRest: "تناسب طريقة عملك", sub: "من طبيب واحد إلى مستشفى كاملة، اختر الأدوات التي تحتاجها لإدارة رحلة المريض بذكاء.",
      value1: "توثيق ذكي بالـAI", value2: "رحلة مريض متصلة", value3: "بيانات آمنة ومشفّرة" },
    region: { title: "كل الأسعار بالجنيه المصري 🇪🇬" },
    limited: { badge: "الأسعار الحالية لفترة محدودة" },
    billing: { monthly: "شهري", yearly: "سنوي", save: "وفر حتى 20% عند الدفع السنوي" },
    perMonth: "/شهر",
    doctors: {
      title: "للأطباء الأفراد",
      cardsClinic: "100 بطاقة مريض", cardsEmergency: "100 بطاقة مريض", cardsInpatient: "حتى 50 مريض نشط",
      clinicName: "العيادات", clinicF1: "توثيق بالصوت والنص", clinicF2: "تاريخ المريض الطبي", clinicF3: "الوصفة الطبية", clinicF4: "روشتة PDF", clinicF5: "الملفات والمرفقات",
      emergencyName: "الطوارئ", emergencyF1: "توثيق الحالات بالصوت", emergencyF2: "العلامات الحيوية", emergencyF3: "الطلبات والمرفقات", emergencyF4: "دخول وخروج المريض", emergencyF5: "نقل للأقسام",
      inpatientName: "التنويم (الراوند)", inpatientF1: "متابعة الراوند اليومية", inpatientF2: "العلامات الحيوية", inpatientF3: "التحاليل والنتائج", inpatientF4: "الخطة العلاجية", inpatientF5: "ملاحظات الطبيب",
      badge: "الأكثر اختيارًا", proTagline: "كل الأدوات في خطة واحدة", proName: "Doctor Pro",
      proF1: "العيادات + الطوارئ + التنويم", proF2: "توثيق AI متقدم بالكامل", proF3: "نقل المريض بين الأقسام", proF4: "روشتة PDF وتقارير", proF5: "تحليلات أساسية",
      cta: "ابدأ الآن",
    },
    followup: { step1: "QR كود", step2: "شات المريض", step3: "ذكاء اصطناعي", step4: "إشعار للطبيب",
      title: "تابع مرضاك حتى بعد الزيارة", desc: "الروشتة بتحمل QR كود بيفتح شات خاص متصل بملف المريض — يقدر يبعت شكواه وصور وتحاليل، وانت تستقبل إشعار فوري بالسياق كامل.",
      cta: "+ إضافة الآن" },
    teams: { title: "للفرق الطبية", team5: "فريق 5", team10: "فريق 10",
      team5F1: "حتى 5 أطباء", team5F2: "1,000 بطاقة مريض مشتركة", team10F1: "حتى 10 أطباء", team10F2: "2,000 بطاقة مريض مشتركة",
      note: "جميع خطط الفرق تشمل صلاحيات وتسليم حالات وتقارير." },
    hospital: { title: "للمستشفيات", sub: "اربط الأطباء والتمريض والأقسام والمرضى في Workflow واحد.",
      wf1: "الطبيب", wf2: "المريض", wf3: "المهمة", wf4: "التمريض", wf5: "مكتملة",
      planName: "خطة احترافية — ابتداءً من", cta: "تواصل مع المبيعات",
      feat1: "حسابات متعددة للأطباء", feat2: "حسابات للتمريض", feat3: "إدارة الأقسام", feat4: "المهام والتنبيهات الذكية", feat5: "لوحة تحكم للمدير", feat6: "تقارير وتحليلات متقدمة" },
    plansNote: "جميع الخطط تشمل صلاحيات مرنة وتقارير مرنة شاملة.",
    why: { p1: "تسعير حسب بطاقات المرضى", p2: "الذكاء الاصطناعي مشمول", p3: "خطط إقليمية مرنة", line: "تدفع مقابل المرضى الذين تديرهم، وليس مقابل كل رسالة AI." },
    faq: {
      title: "الأسئلة الشائعة",
      q1: "ما هي بطاقة المريض؟", a1: "بطاقة المريض هي ملف المريض داخل النظام — تاريخه الطبي، العلامات الحيوية، الطلبات، الملاحظات، والمرفقات، كلها في مكان واحد.",
      q2: "هل يتم احتساب استخدام الذكاء الاصطناعي بشكل منفصل؟", a2: "لا. التسعير مبني على بطاقات المرضى وليس عدد رسائل الذكاء الاصطناعي — استخدمه براحتك ضمن حدود خطتك.",
      q3: "هل يتم احتساب تسجيلات الصوت بشكل منفصل؟", a3: "لا. التسجيل الصوتي يتحول لبيانات منظمة ثم يُحذف — لا يُخزَّن ولا يُحتسب كمورد منفصل.",
      q4: "ماذا يحدث إذا انتقل المريض من الطوارئ للتنويم؟", a4: "نفس بطاقة المريض تنتقل معه — من غير إعادة إدخال، ومن غير احتساب بطاقة جديدة.",
      q5: "هل يمكنني إضافة أطباء لاحقًا؟", a5: "نعم، تقدر تنتقل لخطة فريق أو خطة مستشفى في أي وقت مع نمو عيادتك.",
      q6: "هل يمكن للتمريض استخدام النظام؟", a6: "نعم، في خطط المستشفيات. كل ممرض له حساب خاص ويشوف بس المهام اللازمة لشغله، مش الملف الطبي الكامل.",
      q7: "هل يمكنني إضافة متابعة المرضى لاحقًا؟", a7: "نعم، دي إضافة مستقلة على أي خطة وتقدر تفعّلها في أي وقت.",
      q8: "هل يتوفر الدفع السنوي؟", a8: "نعم — استخدم المفتاح فوق. الدفع السنوي بيوفرلك حتى 20% مقارنة بالشهري.",
      q9: "هل يمكنني تغيير خطتي؟", a9: "نعم، تقدر تنتقل بين الخطط في أي وقت حسب احتياج عيادتك أو مستشفاك.",
    },
    finalCta: { title: "جاهز تبسّط طريقة إدارتك للمرضى؟", sub: "ابدأ الآن وجرّب طريقة أذكى لتوثيق وإدارة رحلة المريض.", primary: "ابدأ تجربتك المجانية", secondary: "تواصل مع المبيعات" },
    phoneName: "د. سارة", phoneMsg1: "عندي صداع خفيف من امبارح", phoneMsg2: "طبيعي بعد الإجراء، هتابع معاك خلال ساعات",
    footer: "© Awn Care — جزء من عائلة Awn Agents",
  },
  en: {
    nav: { app: "App", products: "Products", pricing: "Pricing", contact: "Contact", cta: "Try the app" },
    hero: { titleAccent: "Plans", titleRest: "that fit the way you practice.", sub: "From a single doctor to an entire hospital, choose the tools you need to manage the patient journey with AI.",
      value1: "AI-powered documentation", value2: "Connected patient workflow", value3: "Secure clinical data" },
    region: { title: "All prices in Egyptian Pound 🇪🇬" },
    limited: { badge: "Current prices are for a limited time" },
    billing: { monthly: "Monthly", yearly: "Yearly", save: "Save up to 20% with annual billing" },
    perMonth: "/mo",
    doctors: {
      title: "For Individual Doctors",
      cardsClinic: "100 Patient Cards", cardsEmergency: "100 Patient Cards", cardsInpatient: "Up to 50 active patients",
      clinicName: "Clinic", clinicF1: "Voice & text documentation", clinicF2: "Patient history", clinicF3: "Prescription", clinicF4: "Prescription PDF", clinicF5: "Attachments",
      emergencyName: "Emergency", emergencyF1: "Voice documentation", emergencyF2: "Vital signs", emergencyF3: "Orders & attachments", emergencyF4: "Admission & discharge", emergencyF5: "Department transfer",
      inpatientName: "Inpatient", inpatientF1: "Daily rounds", inpatientF2: "Vital signs", inpatientF3: "Lab results", inpatientF4: "Treatment plan", inpatientF5: "Doctor notes",
      badge: "Most Popular", proTagline: "Everything in one plan", proName: "Doctor Pro",
      proF1: "Clinic + Emergency + Inpatient", proF2: "Full AI documentation", proF3: "Patient transfer", proF4: "Prescription PDF & reports", proF5: "Basic analytics",
      cta: "Get Started",
    },
    followup: { step1: "QR Code", step2: "Patient Chat", step3: "AI", step4: "Doctor Notification",
      title: "Stay connected after the visit.", desc: "The prescription carries a QR code that opens a private chat tied to the patient's record — they send complaints, photos and results, and you get a full-context notification.",
      cta: "+ Add to my plan" },
    teams: { title: "For Medical Teams", team5: "Team 5", team10: "Team 10",
      team5F1: "Up to 5 doctors", team5F2: "1,000 shared Patient Cards", team10F1: "Up to 10 doctors", team10F2: "2,000 shared Patient Cards",
      note: "All team plans include permissions, handover, and reporting." },
    hospital: { title: "For Hospitals", sub: "Connect doctors, nurses, departments and patients in one clinical workflow.",
      wf1: "Doctor", wf2: "Patient", wf3: "Task", wf4: "Nurse", wf5: "Completed",
      planName: "Professional Plan — Starting from", cta: "Talk to Sales",
      feat1: "Multiple doctor accounts", feat2: "Nursing accounts", feat3: "Department management", feat4: "Tasks & smart notifications", feat5: "Management dashboard", feat6: "Advanced analytics & reporting" },
    plansNote: "All plans include flexible permissions and comprehensive reporting.",
    why: { p1: "Patient Card pricing", p2: "AI included", p3: "Flexible regional plans", line: "Pay for the patients you manage — not every AI interaction." },
    faq: {
      title: "Frequently Asked Questions",
      q1: "What is a Patient Card?", a1: "A Patient Card is the patient's record inside the system — history, vitals, orders, notes, and attachments, all in one place.",
      q2: "Does AI usage cost extra?", a2: "No. Pricing is based on Patient Cards, not the number of AI messages — use it as much as you need within your plan.",
      q3: "Are Voice Notes charged separately?", a3: "No. Voice notes are converted into structured data, then deleted — never stored or billed as a separate resource.",
      q4: "What happens when a patient moves from Emergency to Inpatient?", a4: "The same Patient Card follows them — nothing is re-entered, and it doesn't count as a new card.",
      q5: "Can I add more doctors later?", a5: "Yes, you can move to a Team or Hospital plan at any time as your practice grows.",
      q6: "Can nurses use the platform?", a6: "Yes, on Hospital plans. Each nurse gets their own account and sees only the tasks needed for their work, not the full record.",
      q7: "Can I add Patient Follow-up later?", a7: "Yes, it's an independent add-on on any plan and can be turned on whenever you're ready.",
      q8: "Is annual billing available?", a8: "Yes — use the toggle above. Annual billing saves up to 20% compared to monthly.",
      q9: "Can I change my plan?", a9: "Yes, you can switch plans at any time as your practice or hospital's needs change.",
    },
    finalCta: { title: "Ready to simplify the way you manage patients?", sub: "Start now and try a smarter way to document and manage the patient journey.", primary: "Start free trial", secondary: "Talk to Sales" },
    phoneName: "Dr. Sara", phoneMsg1: "I've had a mild headache since yesterday", phoneMsg2: "Normal after the procedure — I'll follow up within hours",
    footer: "© Awn Care — part of the Awn Agents family",
  },
};

const state = { lang: "ar", billing: "monthly" };

function fmtMoney(monthly, currency, lang, yearly) {
  const val = yearly ? Math.round(monthly * 0.8) : monthly;
  if (currency === "egp") return val.toLocaleString("en-US") + (lang === "ar" ? " جنيه" : " EGP");
  return "$" + val.toLocaleString("en-US");
}

function getPath(obj, path) {
  return path.split(".").reduce((o, k) => (o == null ? o : o[k]), obj);
}

function render() {
  const { lang, billing } = state;
  const t = TXT[lang];
  const r = PRICING;
  const yearly = billing === "yearly";

  document.documentElement.setAttribute("lang", lang);
  document.documentElement.setAttribute("dir", lang === "ar" ? "rtl" : "ltr");
  document.body.classList.toggle("lang-ar", lang === "ar");
  document.body.classList.toggle("lang-en", lang === "en");

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const val = getPath(t, el.getAttribute("data-i18n"));
    if (val != null) el.textContent = val;
  });

  document.getElementById("label-monthly").classList.toggle("active", !yearly);
  document.getElementById("label-yearly").classList.toggle("active", yearly);
  document.getElementById("toggle-knob").classList.toggle("yearly", yearly);

  document.getElementById("price-clinic").textContent = fmtMoney(r.clinic, r.currency, lang, yearly);
  document.getElementById("price-emergency").textContent = fmtMoney(r.emergency, r.currency, lang, yearly);
  document.getElementById("price-inpatient").textContent = fmtMoney(r.inpatient, r.currency, lang, yearly);
  document.getElementById("price-pro").textContent = fmtMoney(r.pro, r.currency, lang, yearly);
  document.getElementById("price-followup").textContent = "+" + fmtMoney(r.followup, r.currency, lang, yearly);
  document.getElementById("price-team5").textContent = fmtMoney(r.team5, r.currency, lang, yearly);
  document.getElementById("price-team10").textContent = fmtMoney(r.team10, r.currency, lang, yearly);
  document.getElementById("price-hospital").textContent = fmtMoney(r.hospital, r.currency, lang, yearly);
}

function setLang(l) { state.lang = l; render(); }
function toggleBilling() { state.billing = state.billing === "monthly" ? "yearly" : "monthly"; render(); }

window.setLang = setLang;
window.toggleBilling = toggleBilling;

render();
