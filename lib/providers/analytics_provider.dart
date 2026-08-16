import 'package:flutter/foundation.dart';

import '../models/analytics_summary.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

/// عيادة (source='clinic') طبيعة شغلها مختلفة تمامًا عن الطوارئ/الراوند —
/// فبتحسب لوحدها. hospital بتغطي ed و round مع بعض (نفس رحلة المريض
/// المستمرة في المستشفى).
enum AnalyticsScope { hospital, clinic }

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider({
    required SupabaseService supabaseService,
    required String entryCode,
    required bool hasHospital,
    required bool hasClinic,
    String hospitalBotKey = 'ed',
  })  : _supabaseService = supabaseService,
        _entryCode = entryCode,
        _hasHospital = hasHospital,
        _hasClinic = hasClinic,
        _hospitalBotKey = hospitalBotKey,
        _scope = hasHospital ? AnalyticsScope.hospital : AnalyticsScope.clinic {
    load();
  }

  final SupabaseService _supabaseService;
  final String _entryCode;
  final bool _hasHospital;
  final bool _hasClinic;
  final String _hospitalBotKey;

  AnalyticsScope _scope;
  AnalyticsSummary? _summary;
  bool _isLoading = false;
  String? _error;

  bool get hasHospital => _hasHospital;
  bool get hasClinic => _hasClinic;
  AnalyticsScope get scope => _scope;
  AnalyticsSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setScope(AnalyticsScope scope) {
    if (_scope == scope) return;
    _scope = scope;
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // بوت مختلف حسب النطاق المختار — clinic لوحدها، أو ed/round (أول
      // واحد مشترك فيه الدكتور) للمستشفى — عشان الأرقام متتخلطش مع بعض.
      final botKey = _scope == AnalyticsScope.clinic ? 'clinic' : _hospitalBotKey;
      _summary = await _supabaseService.analyticsSummary(entryCode: _entryCode, botKey: botKey);
    } catch (e) {
      _error = describeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
