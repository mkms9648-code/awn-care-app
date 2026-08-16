import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/encounter.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

class BoardProvider extends ChangeNotifier {
  BoardProvider({
    required SupabaseService supabaseService,
    required String entryCode,
    required String botKey,
    String? workspaceId,
  })  : _supabaseService = supabaseService,
        _entryCode = entryCode,
        _botKey = botKey,
        _workspaceId = workspaceId {
    _startPolling();
    _subscribeRealtime();
  }

  final SupabaseService _supabaseService;
  final String _entryCode;
  final String _botKey;
  final String? _workspaceId;

  List<Encounter> _encounters = [];
  EncounterFilter _filter = EncounterFilter.all;
  String _searchQuery = '';
  DateTime? _filterDate;
  String? _unitFilter;
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

  /// بيفلتر بالاسم/الـ MRN/رقم التذكرة (وبتاريخ الفتح لو فلتر تاريخ متفعّل) على
  /// البيانات المحمّلة أصلًا — من غير نداء جديد للسيرفر، عشان البحث يبقى
  /// فوري وإنت بتكتب. في تاب الراوند بس بيدور بالقسم (unit) كمان.
  List<Encounter> get encounters {
    final q = _searchQuery.trim().toLowerCase();
    Iterable<Encounter> list = _encounters;
    if (_filterDate != null) {
      list = list.where((e) {
        final opened = e.openedAt;
        if (opened == null) return false;
        return opened.year == _filterDate!.year &&
            opened.month == _filterDate!.month &&
            opened.day == _filterDate!.day;
      });
    }
    if (_unitFilter != null) {
      list = list.where((e) => e.unit == _unitFilter);
    }
    if (q.isNotEmpty) {
      list = list.where((e) {
        return e.patientName.toLowerCase().contains(q) ||
            e.mrn.toLowerCase().contains(q) ||
            (e.handle?.toLowerCase().contains(q) ?? false) ||
            (_botKey == 'round' && (e.unit?.toLowerCase().contains(q) ?? false));
      });
    }
    return list.toList();
  }

  EncounterFilter get filter => _filter;
  String get searchQuery => _searchQuery;
  DateTime? get filterDate => _filterDate;
  String? get unitFilter => _unitFilter;
  bool get isTodayFilter => _filterDate != null && _isSameDay(_filterDate!, DateTime.now());
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// زرار "Today": لو الفلتر أصلًا على النهاردة بيشيله، غير كده بيحطه على
  /// النهاردة.
  void toggleToday() {
    final now = DateTime.now();
    if (_filterDate != null && _isSameDay(_filterDate!, now)) {
      _filterDate = null;
    } else {
      _filterDate = DateTime(now.year, now.month, now.day);
    }
    notifyListeners();
  }

  /// زرار فلتر التاريخ المخصص — يفلتر بأي يوم تاني يختاره الطبيب.
  void setCustomDate(DateTime date) {
    _filterDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void clearDateFilter() {
    if (_filterDate == null) return;
    _filterDate = null;
    notifyListeners();
  }

  /// فلتر القسم (units) — تاب الراوند بس. null = كل الأقسام. الفلترة بتتم
  /// client-side على البيانات المحمّلة (بالاسم الظاهر للقسم).
  void setUnitFilter(String? unit) {
    if (_unitFilter == unit) return;
    _unitFilter = unit;
    notifyListeners();
  }

  Future<void> loadEncounters() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _encounters = await _supabaseService.encounterList(
        entryCode: _entryCode,
        botKey: _botKey,
        filter: _filter,
      );
    } catch (e) {
      _error = describeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(EncounterFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    loadEncounters();
  }

  void _startPolling() {
    loadEncounters();
    if (AppConfig.useMockData) {
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => loadEncounters());
    }
  }

  void _subscribeRealtime() {
    if (_workspaceId == null) return;
    _channel = _supabaseService.subscribeEncounters(
      workspaceId: _workspaceId,
      onChange: loadEncounters,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
