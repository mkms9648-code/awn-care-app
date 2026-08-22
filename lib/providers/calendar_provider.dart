import 'package:flutter/foundation.dart';

import '../models/calendar_followup.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// شهر معروض في الكاليندر + اليوم المختار — بيحمّل شهر كامل (زائد أطراف
/// الأسابيع الناقصة أول وآخر الشهر) في نداء واحد بدل ما يجيب كل يوم لوحده.
class CalendarProvider extends ChangeNotifier {
  CalendarProvider({required SupabaseService supabaseService, required String entryCode})
      : _supabaseService = supabaseService,
        _entryCode = entryCode,
        _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1),
        _selectedDay = _dateOnly(DateTime.now()) {
    load();
  }

  final SupabaseService _supabaseService;
  final String _entryCode;

  DateTime _focusedMonth;
  DateTime _selectedDay;
  List<CalendarFollowUp> _items = [];
  bool _isLoading = false;
  String? _error;

  DateTime get focusedMonth => _focusedMonth;
  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// أول يوم من الأسبوع اللي بيبدأ فيه الشهر (السبت أول الأسبوع، نفس تقويم
  /// مصر)، لحد آخر يوم من الأسبوع اللي بينتهي فيه — عشان الشبكة تبقى صفوف
  /// كاملة دايمًا. DateTime.weekday: Monday=1 ... Saturday=6, Sunday=7.
  DateTime get gridStart {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final back = (first.weekday - 6 + 7) % 7;
    return first.subtract(Duration(days: back));
  }

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
}
