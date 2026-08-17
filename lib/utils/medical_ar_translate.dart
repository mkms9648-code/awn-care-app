/// ترجمة عربية "آمنة" لجرعة/طريقة استخدام الدواء بس — قاموس مصطلحات طبية
/// ثابتة ومعروفة (مش ترجمة آلية حرة لنص عشوائي). أي مصطلح مش موجود في
/// القاموس بيرجع زي ما هو من غير تغيير — أحسن من تخمين ترجمة غلط لحاجة
/// طبية. اسم الدواء نفسه عمدًا **مش** بيتترجم أبدًا (يفضل انجليزي زي ما هو
/// مكتوب على العلبة/الروشتة الأصلية، تجنبًا لأي التباس في الصيدلية).
library;

const _routeMap = {
  'po': 'عن طريق الفم',
  'oral': 'عن طريق الفم',
  'by mouth': 'عن طريق الفم',
  'iv': 'عن طريق الوريد',
  'intravenous': 'عن طريق الوريد',
  'im': 'عن طريق العضل',
  'intramuscular': 'عن طريق العضل',
  'sc': 'تحت الجلد',
  'subq': 'تحت الجلد',
  'subcutaneous': 'تحت الجلد',
  'topical': 'موضعي (على الجلد)',
  'sublingual': 'تحت اللسان',
  'sl': 'تحت اللسان',
  'rectal': 'شرجي',
  'pr': 'شرجي',
  'inhaled': 'استنشاق',
  'inhalation': 'استنشاق',
  'nebulized': 'بخاخ/نيبوليزر',
  'ophthalmic': 'قطرة للعين',
  'eye drop': 'قطرة للعين',
  'otic': 'قطرة للأذن',
  'ear drop': 'قطرة للأذن',
  'nasal': 'بخاخ للأنف',
  'ng': 'عن طريق أنبوبة الأنف والمعدة',
};

const _frequencyMap = {
  'once daily': 'مرة يوميًا',
  'once a day': 'مرة يوميًا',
  'od': 'مرة يوميًا',
  'qd': 'مرة يوميًا',
  'daily': 'مرة يوميًا',
  'twice daily': 'مرتين يوميًا',
  'twice a day': 'مرتين يوميًا',
  'bid': 'مرتين يوميًا',
  'three times daily': '3 مرات يوميًا',
  'three times a day': '3 مرات يوميًا',
  'tid': '3 مرات يوميًا',
  'four times daily': '4 مرات يوميًا',
  'four times a day': '4 مرات يوميًا',
  'qid': '4 مرات يوميًا',
  'every 4 hours': 'كل 4 ساعات',
  'q4h': 'كل 4 ساعات',
  'every 6 hours': 'كل 6 ساعات',
  'q6h': 'كل 6 ساعات',
  'every 8 hours': 'كل 8 ساعات',
  'q8h': 'كل 8 ساعات',
  'every 12 hours': 'كل 12 ساعة',
  'q12h': 'كل 12 ساعة',
  'every other day': 'يوم بعد يوم',
  'weekly': 'أسبوعيًا',
  'once weekly': 'مرة أسبوعيًا',
  'monthly': 'شهريًا',
  'as needed': 'عند اللزوم',
  'prn': 'عند اللزوم',
  'at bedtime': 'قبل النوم',
  'hs': 'قبل النوم',
  'before meals': 'قبل الأكل',
  'ac': 'قبل الأكل',
  'after meals': 'بعد الأكل',
  'pc': 'بعد الأكل',
  'with meals': 'مع الأكل',
  'once': 'مرة واحدة',
  'stat': 'فورًا',
};

const _unitMap = {
  'mg': 'مجم',
  'mgs': 'مجم',
  'milligram': 'مجم',
  'milligrams': 'مجم',
  'g': 'جم',
  'gram': 'جم',
  'grams': 'جم',
  'mcg': 'ميكروجرام',
  'µg': 'ميكروجرام',
  'ml': 'مل',
  'milliliter': 'مل',
  'milliliters': 'مل',
  'tablet': 'قرص',
  'tablets': 'أقراص',
  'tab': 'قرص',
  'tabs': 'أقراص',
  'capsule': 'كبسولة',
  'capsules': 'كبسولات',
  'cap': 'كبسولة',
  'caps': 'كبسولات',
  'drop': 'نقطة',
  'drops': 'نقط',
  'puff': 'بخة',
  'puffs': 'بخات',
  'iu': 'وحدة دولية',
  'unit': 'وحدة',
  'units': 'وحدات',
  'vial': 'أمبولة',
  'vials': 'أمبولات',
  'ampoule': 'أمبولة',
  'ampoules': 'أمبولات',
};

String? _lookup(Map<String, String> map, String input) {
  final key = input.trim().toLowerCase();
  return map[key];
}

/// route كامل ("PO") أو جملة قصيرة فيها كذا كلمة — بيدوّر على أطول تطابق
/// معروف، ولو مالقاش يرجّع النص زي ما هو (آمن، مفيش تخمين).
String translateRoute(String route) {
  final direct = _lookup(_routeMap, route);
  if (direct != null) return direct;
  return route;
}

String translateFrequency(String frequency) {
  final direct = _lookup(_frequencyMap, frequency);
  if (direct != null) return direct;
  return frequency;
}

/// الجرعة بتفضل بنفس الأرقام (عالمية ومفهومة)، بس وحدة القياس (mg/ml/tablet)
/// بتتحول عربي لو معروفة — استبدال أطول توكن متطابق بس، من غير ما يلمس الرقم.
String translateDose(String dose) {
  var result = dose;
  final sortedUnits = _unitMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final unit in sortedUnits) {
    final pattern = RegExp(r'(?<=[\d\s])' + RegExp.escape(unit) + r'\b', caseSensitive: false);
    result = result.replaceAllMapped(pattern, (_) => _unitMap[unit]!);
  }
  return result;
}
