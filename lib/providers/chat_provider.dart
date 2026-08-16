import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/patient_summary.dart';
import '../services/chat_history_store.dart';
import '../services/chat_service.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';

/// Scoped to exactly one patient's encounter, opened fresh whenever the
/// doctor taps the mic/chat button inside that patient's card. There is no
/// standalone multi-patient chat anymore — the patient is always already
/// known from which card is open, so every message carries encounter_id/
/// ticket/patient_name and the AI Agent never has to ask "which patient".
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required ChatService chatService,
    required SupabaseService supabaseService,
    required String entryCode,
    required ChatBotKey bot,
    required String encounterId,
    required String ticket,
    required String patientName,
  })  : _chatService = chatService,
        _supabaseService = supabaseService,
        _entryCode = entryCode,
        _bot = bot,
        _encounterId = encounterId,
        _ticket = ticket,
        _patientName = patientName;

  final ChatService _chatService;
  final SupabaseService _supabaseService;
  final String _entryCode;
  final ChatBotKey _bot;
  final String _encounterId;
  final String _ticket;
  final String _patientName;
  final _uuid = const Uuid();
  final _recorder = AudioRecorder();

  final List<ChatMessage> _messages = [];

  bool _isRecording = false;
  bool _isSending = false;
  String? _error;
  String? _recordingPath;
  DateTime? _recordingStarted;

  ChatBotKey get bot => _bot;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isRecording;
  bool get isSending => _isSending;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: _uuid.v4(),
        isFromUser: false,
        type: ChatMessageType.system,
        text: 'Recording for $_patientName (#$_ticket). Speak or type — vitals, '
            'complaint, notes, orders... it all gets saved to this patient directly.',
      ),
    );
  }

  /// هيستوري محلي دائم لنفس المريض ده — زي تيليجرام، لو الطبيب خرج ورجع
  /// يلاقي كل الرسايل بتاريخها ووقتها. لازم تتنادى بعد الإنشاء مباشرة
  /// (زي: `ChatProvider(...)..loadHistory()`).
  Future<void> loadHistory() async {
    final saved = await ChatHistoryStore.load(_encounterId);
    _messages
      ..clear()
      ..addAll(saved);
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
    notifyListeners();
  }

  void _persist() {
    // Fire-and-forget — الحفظ مش لازم يوقف تحديث الواجهة.
    unawaited(ChatHistoryStore.save(_encounterId, _messages));
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    await _send(type: 'text', text: text.trim(), messageType: ChatMessageType.text);
  }

  Future<void> sendPhoto(File file, {String? caption}) async {
    if (_isSending) return;
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      isFromUser: true,
      type: ChatMessageType.photo,
      text: caption,
      attachments: [ChatAttachment(storagePath: '', localPath: file.path)],
      status: ChatMessageStatus.sending,
    );
    _messages.add(userMsg);
    _isSending = true;
    notifyListeners();

    try {
      final storagePath = await _chatService.uploadAttachment(
        entryCode: _entryCode,
        file: file,
        type: 'photo',
      );
      userMsg.attachments = [
        ChatAttachment(storagePath: storagePath, localPath: file.path, caption: caption),
      ];
      userMsg.status = ChatMessageStatus.sent;

      final response = await _chatService.sendMessage(
        entryCode: _entryCode,
        botKey: _bot,
        type: 'photo',
        photoStoragePath: storagePath,
        caption: caption,
        encounterId: _encounterId,
        ticket: _ticket,
        patientName: _patientName,
      );
      await _handleResponse(response);
    } catch (e) {
      userMsg.status = ChatMessageStatus.failed;
      _error = describeError(e);
    } finally {
      _isSending = false;
      _persist();
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    // path_provider (getTemporaryDirectory) وdart:io.File مش متاحين على الويب
    // خالص — التسجيل الصوتي والصور محتاجين ملف حقيقي على الجهاز، فبيشتغلوا
    // بس على Android/iOS فعليًا. بنمنعها بدري على الويب بدل ما تفشل بصمت.
    if (kIsWeb) {
      _error = 'Voice recording is only available on the mobile app (Android/iOS), not in the browser.';
      notifyListeners();
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _error = 'Microphone permission required.';
        notifyListeners();
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/recording_${_uuid.v4()}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath!);
      _isRecording = true;
      _recordingStarted = DateTime.now();
      notifyListeners();
    } catch (e) {
      _error = 'Could not start recording: $e';
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndSend() async {
    if (!_isRecording || _recordingPath == null) return;
    final path = await _recorder.stop();
    _isRecording = false;
    notifyListeners();

    if (path == null) return;
    final duration = _recordingStarted != null
        ? DateTime.now().difference(_recordingStarted!)
        : const Duration(seconds: 1);

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      isFromUser: true,
      type: ChatMessageType.voice,
      status: ChatMessageStatus.sending,
      audioStoragePath: path,
      audioDuration: duration,
    );
    _messages.add(userMsg);
    _isSending = true;
    notifyListeners();

    try {
      final storagePath = await _chatService.uploadAttachment(
        entryCode: _entryCode,
        file: File(path),
        type: 'voice',
      );
      userMsg.audioStoragePath = storagePath;
      userMsg.status = ChatMessageStatus.sent;

      final response = await _chatService.sendMessage(
        entryCode: _entryCode,
        botKey: _bot,
        type: 'voice',
        audioStoragePath: storagePath,
        encounterId: _encounterId,
        ticket: _ticket,
        patientName: _patientName,
      );
      await _handleResponse(response);
    } catch (e) {
      userMsg.status = ChatMessageStatus.failed;
      _error = describeError(e);
    } finally {
      _isSending = false;
      _recordingPath = null;
      _recordingStarted = null;
      _persist();
      notifyListeners();
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    _isRecording = false;
    _recordingPath = null;
    _recordingStarted = null;
    notifyListeners();
  }

  Future<void> _send({
    required String type,
    required String text,
    required ChatMessageType messageType,
  }) async {
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      isFromUser: true,
      type: messageType,
      text: text,
      status: ChatMessageStatus.sending,
    );
    _messages.add(userMsg);
    _isSending = true;
    notifyListeners();

    try {
      userMsg.status = ChatMessageStatus.sent;
      final response = await _chatService.sendMessage(
        entryCode: _entryCode,
        botKey: _bot,
        type: type,
        text: text,
        encounterId: _encounterId,
        ticket: _ticket,
        patientName: _patientName,
      );
      await _handleResponse(response);
    } catch (e) {
      userMsg.status = ChatMessageStatus.failed;
      _error = describeError(e);
    } finally {
      _isSending = false;
      _persist();
      notifyListeners();
    }
  }

  /// كل شيء بيتسجّل فورًا ويترجع كـ echo، إلا الفيتالز — لسه بتعدّي بمرحلتين
  /// (stage ثم commit) زي ما هو موثّق في الدليل المرجعي، عشان غلطة رقم في
  /// تفريغ صوتي متتسجلش مباشرة في سجل طبي. بدل ما نحاول نخمّن من نص الرد إن
  /// ده "لحظة تأكيد فيتالز"، بنسأل قاعدة البيانات نفسها مباشرة (مصدر الحقيقة)
  /// لو فيه قراءة معلّقة لسه — ده أوثق من أي heuristic نصي.
  Future<void> _handleResponse(WebhookResponse response) async {
    final displayText = ChatMessage.extractDisplayText(response.replyText);

    PendingVitals? pending;
    try {
      pending = await _supabaseService.latestPendingVitals(entryCode: _entryCode, botKey: _bot.value);
    } catch (_) {
      pending = null;
    }

    if (pending != null && pending.encounterId == _encounterId) {
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          isFromUser: false,
          type: ChatMessageType.reviewCard,
          text: displayText,
          reviewCard: ReviewCardData(
            title: 'Confirm Vitals',
            fields: _vitalsToFields(pending.readings),
            confirmAction: 'Save',
            rejectAction: 'Discard',
          ),
          pendingVitals: pending,
          status: ChatMessageStatus.pendingReview,
        ),
      );
    } else {
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          isFromUser: false,
          type: response.attachments.isNotEmpty ? ChatMessageType.photo : ChatMessageType.text,
          text: displayText,
          attachments: response.attachments,
        ),
      );
    }
    notifyListeners();
  }

  static const _metricLabels = {
    'bp_sys': 'Systolic',
    'bp_dia': 'Diastolic',
    'hr': 'Heart Rate',
    'temp': 'Temperature',
    'spo2': 'SpO2',
    'rbs': 'RBS',
    'gcs': 'GCS',
  };

  Map<String, String> _vitalsToFields(List<Map<String, dynamic>> readings) {
    final fields = <String, String>{};
    for (final r in readings) {
      final metric = r['metric']?.toString() ?? '';
      final unit = r['unit']?.toString();
      final baseLabel = _metricLabels[metric] ?? metric;
      final label = unit != null && unit.isNotEmpty ? '$baseLabel ($unit)' : baseLabel;
      fields[label] = '${r['value']}';
    }
    return fields;
  }

  /// [editedFields] لسه في نفس ترتيب وعدد القراءات الأصلية (كارت المراجعة
  /// بيبني حقوله من نفس الـ readings list بالظبط) — القيمة الوحيدة اللي ممكن
  /// تتغيّر هي الرقم نفسه، مش الـ metric أو الـ unit.
  List<Map<String, dynamic>> _applyEditedValues(
    List<Map<String, dynamic>> originalReadings,
    Map<String, String> editedFields,
  ) {
    final editedValues = editedFields.values.toList();
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < originalReadings.length; i++) {
      final reading = Map<String, dynamic>.from(originalReadings[i]);
      final parsed = i < editedValues.length ? double.tryParse(editedValues[i].trim()) : null;
      if (parsed != null) reading['value'] = parsed;
      result.add(reading);
    }
    return result;
  }

  bool _fieldsChanged(Map<String, String> original, Map<String, String> edited) {
    if (original.length != edited.length) return true;
    final originalValues = original.values.toList();
    final editedValues = edited.values.toList();
    for (var i = 0; i < originalValues.length; i++) {
      if (originalValues[i].trim() != editedValues[i].trim()) return true;
    }
    return false;
  }

  Future<void> confirmReviewCard(String messageId, Map<String, String> editedFields) async {
    final msg = _findMessage(messageId);
    final pending = msg?.pendingVitals;
    if (msg?.reviewCard == null || pending == null) return;

    try {
      if (_fieldsChanged(msg!.reviewCard!.fields, editedFields)) {
        final readings = _applyEditedValues(pending.readings, editedFields);
        final restaged = await _supabaseService.stageVitals(
          entryCode: _entryCode,
          botKey: _bot.value,
          encounterId: pending.encounterId,
          readings: readings,
          measuredAt: pending.measuredAt,
        );
        await _supabaseService.commitVitals(
          entryCode: _entryCode,
          botKey: _bot.value,
          pendingId: restaged.pendingId,
        );
      } else {
        await _supabaseService.commitVitals(
          entryCode: _entryCode,
          botKey: _bot.value,
          pendingId: pending.pendingId,
        );
      }

      msg.reviewCard = ReviewCardData(
        title: msg.reviewCard!.title,
        fields: editedFields,
        confirmAction: msg.reviewCard!.confirmAction,
        rejectAction: msg.reviewCard!.rejectAction,
        isConfirmed: true,
      );
      msg.status = ChatMessageStatus.sent;
    } catch (e) {
      _error = describeError(e);
    }
    _persist();
    notifyListeners();
  }

  Future<void> rejectReviewCard(String messageId) async {
    final msg = _findMessage(messageId);
    if (msg?.reviewCard == null) return;

    msg!.reviewCard = ReviewCardData(
      title: msg.reviewCard!.title,
      fields: msg.reviewCard!.fields,
      confirmAction: msg.reviewCard!.confirmAction,
      rejectAction: msg.reviewCard!.rejectAction,
      isConfirmed: false,
    );
    msg.status = ChatMessageStatus.sent;
    _persist();
    notifyListeners();

    _messages.add(
      ChatMessage(
        id: _uuid.v4(),
        isFromUser: false,
        type: ChatMessageType.system,
        text: 'Discarded. Nothing was saved.',
      ),
    );
    notifyListeners();
  }

  ChatMessage? _findMessage(String id) {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
