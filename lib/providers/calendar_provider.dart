import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/analytics_summary.dart';
import '../models/calendar_followup.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// أول سبت على/قبل اليوم ده — أساس حساب الأسبوع في كل الشاشة (نفس تقويم
/// مصر: السبت أول الأسبوع). DateTime.weekday: Monday=1 ... Saturday=6, Sunday=7.
DateTime _saturdayOnOrBefore(DateTime d) {
  final back = (d.weekday - 6 + 7) % 7;
  return _dateOnly(d).subtract(Duration(days: back));
}

const _weekdayLabelsShort = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
final _monthShortFmt = DateFormat('MMM');
final _monthShortYearFmt = DateFormat('MMM yy');

/// شهر معروض في الكاليندر + اليوم المختار، زائد بيانات اتجاهات (Trends) —
/// عدد المتابعات لكل شهر/أسبوع جوه شهر/يوم جوه أسبوع، بالـdrill-down.
/// بيانات الاتجاهات بتتحمّل مرة واحدة بس (نطاق واسع بيغطي كل الشهور)، وكل
/// مستويات الـdrill-down بترشّح نفس القايمة محليًا من غير أي نداء سيرفر جديد.
class CalendarProvider extends ChangeNotifier {
  CalendarProvider({required SupabaseService supabaseService, required String entryCode})
      : _supabaseService = supabaseService,
        _entryCode = entryCode,
        _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1),
        _selectedDay = _dateOnly(DateTime.now()) {
    load();
    loadTrends();
  }

  final SupabaseService _supabaseService;
  final String _entryCode;

  DateTime _focusedMonth;
  DateTime _selectedDay;
  List<CalendarFollowUp> _items = [];
  bool _isLoading = false;
  String? _error;

  List<CalendarFollowUp> _trendItems = [];
  bool _trendsLoading = false;
  String? _trendsError;
  DateTime? _trendMonth; // null = عرض كل الشهور
  int? _trendWeekIndex; // null = عرض أسابيع الشهر المختار

  DateTime get focusedMonth => _focusedMonth;
  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get trendsLoading => _trendsLoading;
  String? get trendsError => _trendsError;
  DateTime? get trendMonth => _trendMonth;
  int? get trendWeekIndex => _trendWeekIndex;

  DateTime get gridStart => _saturdayOnOrBefore(DateTime(_focusedMonth.year, _focusedMonth.month, 1));

  DateTime get gridEnd {
    final lastOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final forward = (5 - lastOfMonth.weekday + 7) % 7;
    return lastOfMonth.add(Duration(days: forward));
  }

  Map<DateTime, List<CalendarFollowUp>> get byDay {
    final map = <DateTime, List<CalendarFollowUp>>{};
    for (final item in _items) {
      final key = _dateOnly(item.dueAt);
      (map[key] ??= []).add(item);
    }
    return map;
  }

  List<CalendarFollowUp> get selectedDayItems => byDay[_dateOnly(_selectedDay)] ?? const [];

  void selectDay(DateTime day) {
    _selectedDay = _dateOnly(day);
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    load();
  }

  void prevMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _supabaseService.calendarFollowUps(
        entryCode: _entryCode,
        from: gridStart,
        to: gridEnd.add(const Duration(days: 1)),
      );
    } catch (e) {
      _error = describeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---- الاتجاهات (Trends): شهر → أسبوع → يوم في الأسبوع ----

  Future<void> loadTrends() async {
    _trendsLoading = true;
    _trendsError = null;
    notifyListeners();

    try {
      final now = _dateOnly(DateTime.now());
      _trendItems = await _supabaseService.calendarFollowUps(
        entryCode: _entryCode,
        from: now.subtract(const Duration(days: 30)),
        to: now.add(const Duration(days: 210)),
      );
    } catch (e) {
      _trendsError = describeError(e);
    } finally {
      _trendsLoading = false;
      notifyListeners();
    }
  }

  void drillIntoMonth(DateTime month) {
    _trendMonth = DateTime(month.year, month.month, 1);
    _trendWeekIndex = null;
    notifyListeners();
  }

  void drillIntoWeek(int weekIndex) {
    _trendWeekIndex = weekIndex;
    notifyListeners();
  }

  /// يطلع مستوى واحد لفوق: يوم-في-أسبوع → أسابيع → شهور.
  void drillUp() {
    if (_trendWeekIndex != null) {
      _trendWeekIndex = null;
    } else {
      _trendMonth = null;
    }
    notifyListeners();
  }

  bool get isMonthLevel => _trendMonth == null;
  bool get isWeekLevel => _trendMonth != null && _trendWeekIndex == null;
  bool get isWeekdayLevel => _trendMonth != null && _trendWeekIndex != null;

  String get trendBreadcrumb {
    if (_trendMonth == null) return 'All months';
    final monthLabel = DateFormat('MMMM yyyy').format(_trendMonth!);
    if (_trendWeekIndex == null) return monthLabel;
    return '$monthLabel · Week ${_trendWeekIndex! + 1}';
  }

  /// عدد المتابعات لكل شهر عبر كل النطاق المحمّل — مرتبة زمنيًا.
  List<LabeledCount> get monthBars {
    if (_trendItems.isEmpty) return const [];
    final counts = <DateTime, int>{};
    for (final item in _trendItems) {
      final key = DateTime(item.dueAt.year, item.dueAt.month, 1);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final months = counts.keys.toList()..sort();
    final spansMultipleYears = months.map((m) => m.year).toSet().length > 1;
    return [
      for (final m in months)
        LabeledCount(
          label: spansMultipleYears ? _monthShortYearFmt.format(m) : _monthShortFmt.format(m),
          count: counts[m]!,
        ),
    ];
  }

  /// نفس ترتيب [monthBars] — يوصلنا للشهر الحقيقي (DateTime) عند الضغط على
  /// عمود، لأن LabeledCount بيحمل نص العرض بس مش القيمة.
  List<DateTime> get monthBarKeys {
    if (_trendItems.isEmpty) return const [];
    final counts = <DateTime, int>{};
    for (final item in _trendItems) {
      final key = DateTime(item.dueAt.year, item.dueAt.month, 1);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts.keys.toList()..sort();
  }

  /// عدد المتابعات لكل أسبوع (بترقيم من 1) جوه [trendMonth] المختار.
  List<LabeledCount> get weekBars {
    final month = _trendMonth;
    if (month == null) return const [];
    final monthGridStart = _saturdayOnOrBefore(month);
    final counts = <int, int>{};
    for (final item in _trendItems) {
      if (item.dueAt.year != month.year || item.dueAt.month != month.month) continue;
      final weekIndex = _dateOnly(item.dueAt).difference(monthGridStart).inDays ~/ 7;
      counts[weekIndex] = (counts[weekIndex] ?? 0) + 1;
    }
    final indices = counts.keys.toList()..sort();
    return [for (final i in indices) LabeledCount(label: 'Week ${i + 1}', count: counts[i]!)];
  }

  List<int> get weekBarKeys {
    final month = _trendMonth;
    if (month == null) return const [];
    final monthGridStart = _saturdayOnOrBefore(month);
    final counts = <int, int>{};
    for (final item in _trendItems) {
      if (item.dueAt.year != month.year || item.dueAt.month != month.month) continue;
      final weekIndex = _dateOnly(item.dueAt).difference(monthGridStart).inDays ~/ 7;
      counts[weekIndex] = (counts[weekIndex] ?? 0) + 1;
    }
    return counts.keys.toList()..sort();
  }

  /// عدد المتابعات لكل يوم في الأسبوع (سبت..جمعة) جوه الأسبوع المختار
  /// [trendWeekIndex] من [trendMonth].
  List<LabeledCount> get weekdayBars {
    final month = _trendMonth;
    final weekIndex = _trendWeekIndex;
    if (month == null || weekIndex == null) return const [];
    final monthGridStart = _saturdayOnOrBefore(month);
    final weekStart = monthGridStart.add(Duration(days: weekIndex * 7));
    final counts = List<int>.filled(7, 0);
    for (final item in _trendItems) {
      final day = _dateOnly(item.dueAt);
      final offset = day.difference(weekStart).inDays;
      if (offset >= 0 && offset < 7) counts[offset]++;
    }
    return [for (var i = 0; i < 7; i++) LabeledCount(label: _weekdayLabelsShort[i], count: counts[i])];
  }
}
