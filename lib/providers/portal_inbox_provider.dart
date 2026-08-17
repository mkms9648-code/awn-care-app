import 'package:flutter/foundation.dart';

import '../models/portal_escalation.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

/// يغذّي شاشة صندوق وارد التصعيدات (تاب المساعد) — نفس شكل [BoardProvider]
/// (fetch/loading/error/refresh) لكن مبني على app_portal_inbox بدل
/// app_encounter_list، وبفلتر status بدل EncounterFilter.
class PortalInboxProvider extends ChangeNotifier {
  PortalInboxProvider({
    required SupabaseService supabaseService,
    required String entryCode,
  })  : _supabaseService = supabaseService,
        _entryCode = entryCode {
    loadInbox();
  }

  final SupabaseService _supabaseService;
  final String _entryCode;

  List<PortalEscalation> _escalations = [];
  String _status = 'open';
  bool _isLoading = false;
  String? _error;

  List<PortalEscalation> get escalations => _escalations;
  String get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInbox() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _escalations = await _supabaseService.portalInbox(
        entryCode: _entryCode,
        status: _status,
      );
    } catch (e) {
      _error = describeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatus(String status) {
    if (_status == status) return;
    _status = status;
    loadInbox();
  }
}
