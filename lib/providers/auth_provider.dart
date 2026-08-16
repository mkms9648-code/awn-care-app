import 'package:flutter/foundation.dart';

import '../models/staff_profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required SupabaseService supabaseService,
  })  : _authService = authService,
        _supabaseService = supabaseService;

  final AuthService _authService;
  final SupabaseService _supabaseService;

  String? _entryCode;
  StaffProfile? _profile;
  bool _isLoading = false;
  String? _error;

  String? get entryCode => _entryCode;
  StaffProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _entryCode != null && _profile != null;

  Future<void> tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final code = await _authService.getEntryCode();
      if (code != null && code.length == 6) {
        _entryCode = code;
        final deviceId = await _authService.getOrCreateDeviceId();
        _profile = await _supabaseService.resolveStaff(code, deviceId: deviceId);
      }
    } catch (e) {
      _error = describeError(e);
      await _authService.clearEntryCode();
      _entryCode = null;
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String code) async {
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _error = 'Please enter a valid 6-digit code.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final deviceId = await _authService.getOrCreateDeviceId();
      final profile = await _supabaseService.resolveStaff(code, deviceId: deviceId);
      await _authService.saveEntryCode(code);
      _entryCode = code;
      _profile = profile;
      return true;
    } catch (e) {
      _error = describeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// لاحظ: عمدًا مش بنمسح الكود المخزّن هنا (clearEntryCode) — الهدف إن
  /// شاشة الدخول تفضل حاطة الكود جاهز في المرة الجاية (راجع LoginScreen)،
  /// الطبيب يقدر يمسحه بنفسه لو عايز يدخل بكود تاني.
  Future<void> logout() async {
    _entryCode = null;
    _profile = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
