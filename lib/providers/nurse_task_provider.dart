import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/nurse_task.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

/// قايمة مهام الممرض/ة — بولينج بسيط (مفيش realtime subscription في v1،
/// القايمة مش متوقع يتغيّر عليها حاجة كل ثانية زي بورد الدكتور).
class NurseTaskProvider extends ChangeNotifier {
  NurseTaskProvider({required SupabaseService supabaseService, required String entryCode})
      : _supabaseService = supabaseService,
        _entryCode = entryCode {
    load();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => load());
  }

  final SupabaseService _supabaseService;
  final String _entryCode;
  Timer? _pollTimer;

  List<NurseTask> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<NurseTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _supabaseService.nurseTaskList(entryCode: _entryCode);
    } catch (e) {
      _error = describeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
