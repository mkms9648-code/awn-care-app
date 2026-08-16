import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/patient_summary.dart';
import '../models/unit_info.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_utils.dart';
import '../utils/error_utils.dart';
import '../utils/prescription_pdf.dart';
import '../utils/report_formatter.dart';
import '../utils/report_pdf.dart';
import '../utils/ticket_utils.dart';
import '../widgets/collapsible_section.dart';
import '../widgets/history_list_views.dart';
import '../widgets/vitals_history_view.dart';
import '../widgets/zoomable_attachment_image.dart';
import 'chat_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.encounterId,
    required this.botKey,
  });

  final String encounterId;
  final String botKey;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  PatientSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _actionInProgress = false;

  // بيانات الأقسام القابلة للطي اللي بتتحمّل lazy أول ما القسم يتفتح —
  // نفس البيانات بتفضل محفوظة هنا (مش جوه CollapsibleSection) عشان لو
  // القسم اتقفل وفتح تاني، مايعيدش النداء للسيرفر.
  List<VitalHistoryReading>? _vitalsHistory;
  List<MedicationHistoryEntry>? _prescriptionHistory;
  List<NoteHistoryEntry>? _historyNotes;
  List<NoteHistoryEntry>? _alertsNotes;
  List<NoteHistoryEntry>? _treatmentPlanNotes;
  List<NoteHistoryEntry>? _resultsNotes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final summary = await context.read<SupabaseService>().patientSummary(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
          );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVitalsHistory() async {
    final auth = context.read<AuthProvider>();
    final data = await context.read<SupabaseService>().vitalsHistory(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
        );
    if (mounted) setState(() => _vitalsHistory = data);
  }

  Future<void> _loadPrescriptionHistory() async {
    final auth = context.read<AuthProvider>();
    final data = await context.read<SupabaseService>().medicationsHistory(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
        );
    if (mounted) setState(() => _prescriptionHistory = data);
  }

  Future<void> _loadNotesByKind(String kind, void Function(List<NoteHistoryEntry>) assign) async {
    final auth = context.read<AuthProvider>();
    final data = await context.read<SupabaseService>().notesHistory(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
          kind: kind,
        );
    if (mounted) setState(() => assign(data));
  }

  Future<void> _confirmDischarge() async {
    final isClinic = _summary?.encounter.source == 'clinic';
    final actionLabel = isClinic ? 'Close Visit' : 'Discharge';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isClinic ? 'Close Visit' : 'Discharge Patient'),
        content: Text(isClinic
            ? 'Close this visit for ${_summary?.patient.name ?? 'this patient'}?'
            : 'Discharge ${_summary?.patient.name ?? 'this patient'}? This closes the encounter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(actionLabel)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<SupabaseService>().dischargeEncounter(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isClinic ? 'Visit closed.' : 'Patient discharged.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _showAdmitDialog() async {
    final auth = context.read<AuthProvider>();
    final supabase = context.read<SupabaseService>();

    List<UnitInfo> units;
    try {
      units = await supabase.listUnits(entryCode: auth.entryCode!, botKey: widget.botKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
      return;
    }
    if (!mounted) return;

    final chosen = await showDialog<UnitInfo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Admit To Which Unit?'),
        children: units.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('No units found for this organization.'),
                ),
              ]
            : units
                .map((u) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, u),
                      child: Text(u.name),
                    ))
                .toList(),
      ),
    );
    if (chosen == null || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      await supabase.admitToUnit(
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        encounterId: widget.encounterId,
        unit: chosen,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Admitted to ${chosen.name}.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _saveAttachmentsToGallery() async {
    if (_summary == null || _summary!.attachments.isEmpty || _actionInProgress) return;
    final chatService = context.read<ChatService>();
    setState(() => _actionInProgress = true);
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        throw Exception('Photo library access denied.');
      }
      var saved = 0;
      for (final a in _summary!.attachments) {
        final url = await chatService.getSignedUrl(a.storagePath);
        if (url == null) continue;
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;
        await Gal.putImageBytes(response.bodyBytes, name: 'awn_care_${a.id}');
        saved++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $saved photo(s) to gallery.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _exportPatientReport() async {
    if (_summary == null) return;
    try {
      await shareReportPdf(
        subject: 'Patient Report — ${_summary!.patient.name}',
        body: formatPatientReport(_summary!),
        filename: 'awn-care-${_summary!.patient.name}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    }
  }

  Future<void> _exportPrescription() async {
    if (_summary == null) return;
    if (_summary!.activeMedications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active medications to include in a prescription.')),
      );
      return;
    }
    try {
      await sharePrescriptionPdf(_summary!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    }
  }

  /// تنفيذ أوردر — إجراء اتجاه واحد بس من الواجهة (مفيش تراجع باللمسة، الدكتور
  /// طلب صراحة إن الحاجة لما تتعمل done أو تتمسح تفضل كده وميرجعش لايف تاني).
  /// قبل ما تتقفل، بيسأل اختياري لو عايز يسجل النتيجة (تحليل/أشعة) — لو
  /// دخلها، بتتسجل كـ note منفصلة (kind='result') تظهر في قسم "نتائج
  /// التحاليل/الأشعة" المستقل، جنب order_completed في نفس النداء.
  Future<void> _completeOrder(OrderInfo o) async {
    if (_actionInProgress || !o.isPending) return;

    final nameController = TextEditingController(text: o.name);
    final resultController = TextEditingController();
    final addResult = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optionally record the result now (skip if not ready yet):',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Test')),
            const SizedBox(height: 12),
            TextField(
              controller: resultController,
              decoration: const InputDecoration(labelText: 'Result'),
              maxLines: 2,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Just Mark Done')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (addResult == null || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      final resultText = resultController.text.trim();
      if (addResult && resultText.isNotEmpty) {
        await supabase.completeOrderWithResult(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
          orderId: o.id,
          testName: nameController.text.trim().isEmpty ? o.name : nameController.text.trim(),
          result: resultText,
        );
      } else {
        await supabase.completeOrder(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
          orderId: o.id,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _cancelOrder(OrderInfo o) async {
    if (_actionInProgress) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Cancel "${o.name}"? This cannot be undone from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Order')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      await supabase.cancelOrder(
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        encounterId: widget.encounterId,
        orderId: o.id,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _runAddAction(Future<void> Function() action, {required String successMessage}) async {
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  static const _orderCategories = ['lab', 'imaging', 'consult', 'procedure'];
  // history/health_education/treatment_plan/result بقى ليهم أقسام مخصصة
  // (History/Alerts/Treatment Plan/Results) — مش هنا عشان مايتكررش نفس
  // الملاحظة في مكانين.
  static const _noteKinds = ['complaint', 'exam', 'diagnosis'];
  static const _vitalMetricLabels = {
    'bp': 'Blood Pressure',
    'hr': 'Heart Rate',
    'temp': 'Temperature',
    'spo2': 'SpO2',
    'rbs': 'RBS',
    'gcs': 'GCS',
  };
  static const _vitalDefaultUnits = {
    'hr': 'bpm',
    'temp': '°C',
    'spo2': '%',
    'rbs': 'mg/dL',
    'gcs': '',
  };

  /// اسم البوت الخاص بالتاب ده كـ ChatBotKey — لفتح شات مخصّص لنفس المريض.
  ChatBotKey get _chatBotKey {
    switch (widget.botKey) {
      case 'round':
        return ChatBotKey.round;
      case 'clinic':
        return ChatBotKey.clinic;
      default:
        return ChatBotKey.ed;
    }
  }

  /// زرار الشات/المايك فوق الكارت — بيفتح تسجيل صوت/كتابة مربوط بنفس المريض
  /// ده تلقائيًا (encounter_id بيتبعت صريح مع كل رسالة)، فمفيش أي حاجة
  /// تتقال محتاجة توضيح "مين المريض المقصود؟". لما يقفل، بيحدّث الكارت
  /// عشان أي حاجة اتسجلت من الشات تبان فورًا.
  void _openPatientChat() {
    if (_summary == null) return;
    final auth = context.read<AuthProvider>();
    final rawHandle = _summary!.encounter.handle;
    final ticket = rawHandle != null ? cleanTicket(rawHandle) : '';
    final chatService = context.read<ChatService>();
    final supabase = context.read<SupabaseService>();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(
                chatService: chatService,
                supabaseService: supabase,
                entryCode: auth.entryCode!,
                bot: _chatBotKey,
                encounterId: widget.encounterId,
                ticket: ticket,
                patientName: _summary!.patient.name,
              )..loadHistory(),
              child: ChatScreen(title: '${_summary!.patient.name} — #$ticket'),
            ),
          ),
        )
        .then((_) => _load());
  }

  Future<void> _showAddComplicationDialog() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Complication'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true || controller.text.trim().isEmpty || !mounted) return;
    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addComplication(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            description: controller.text.trim(),
          ),
      successMessage: 'Complication added.',
    );
  }

  Future<void> _showAddPhotoMenu() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final chatService = context.read<ChatService>();
    final supabase = context.read<SupabaseService>();
    await _runAddAction(
      () async {
        final storagePath = await chatService.uploadAttachment(
          entryCode: auth.entryCode!,
          file: File(file.path),
          type: 'image',
        );
        await supabase.addAttachment(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: widget.encounterId,
          storagePath: storagePath,
        );
      },
      successMessage: 'Photo added.',
    );
  }

  Future<void> _showAddOrderDialog() async {
    final nameController = TextEditingController();
    String category = _orderCategories.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _orderCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Order name'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty || !mounted) return;
    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addOrder(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            category: category,
            name: nameController.text.trim(),
          ),
      successMessage: 'Order added.',
    );
  }

  /// فورم عام لأي قسم "ملاحظة موسومة" (History/التنبيهات وتعليمات العلاج/خطة
  /// العلاج) — kind ثابت حسب القسم، فمفيش قائمة اختيار زي فورم الملاحظات
  /// العادي. بيحدّث الداتا الخاصة بالقسم ده بس بعد الإضافة (مش الملخص كله).
  Future<void> _showKindNoteDialog({
    required String title,
    required String hint,
    required String kind,
    required void Function(List<NoteHistoryEntry>) assign,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: hint),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || controller.text.trim().isEmpty || !mounted) return;

    final auth = context.read<AuthProvider>();
    setState(() => _actionInProgress = true);
    try {
      await context.read<SupabaseService>().addNote(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            kind: kind,
            body: controller.text.trim(),
          );
      await _loadNotesByKind(kind, assign);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _showAddResultDialog() async {
    final testController = TextEditingController();
    final resultController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: testController, decoration: const InputDecoration(labelText: 'Test'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: resultController, decoration: const InputDecoration(labelText: 'Result'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || testController.text.trim().isEmpty || resultController.text.trim().isEmpty || !mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _actionInProgress = true);
    try {
      await context.read<SupabaseService>().addNote(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            kind: 'result',
            body: '${testController.text.trim()}: ${resultController.text.trim()}',
          );
      await _loadNotesByKind('result', (v) => _resultsNotes = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _showAddNoteDialog() async {
    final bodyController = TextEditingController();
    String kind = _noteKinds.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: _noteKinds.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) => setDialogState(() => kind = v ?? kind),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || bodyController.text.trim().isEmpty || !mounted) return;
    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addNote(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            kind: kind,
            body: bodyController.text.trim(),
          ),
      successMessage: 'Note added.',
    );
  }

  Future<void> _showAddPrescriptionDialog() async {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final routeController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Drug name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(controller: doseController, decoration: const InputDecoration(labelText: 'Dose (optional)')),
              const SizedBox(height: 12),
              TextField(
                controller: routeController,
                decoration: const InputDecoration(labelText: 'Route (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: 'Frequency (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration in days (optional)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty || !mounted) return;
    final durationDays = int.tryParse(durationController.text.trim());
    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addPrescription(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            name: nameController.text.trim(),
            dose: doseController.text.trim(),
            route: routeController.text.trim(),
            frequency: frequencyController.text.trim(),
            endsAt: durationDays != null ? DateTime.now().add(Duration(days: durationDays)) : null,
          ),
      successMessage: 'Prescription added.',
    );
  }

  Future<void> _showAddFollowUpDialog() async {
    final textController = TextEditingController(text: 'Follow-up visit');
    final daysController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Follow-up'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Reason'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                decoration: const InputDecoration(labelText: 'In how many days'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    final days = int.tryParse(daysController.text.trim());
    if (confirmed != true || textController.text.trim().isEmpty || days == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addFollowUp(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            text: textController.text.trim(),
            dueAt: DateTime.now().add(Duration(days: days)),
          ),
      successMessage: 'Follow-up added.',
    );
  }

  Future<void> _showAddVitalDialog() async {
    String metric = 'bp';
    final sysController = TextEditingController();
    final diaController = TextEditingController();
    final valueController = TextEditingController();
    final unitController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Vital'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: metric,
                  decoration: const InputDecoration(labelText: 'Metric'),
                  items: _vitalMetricLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() {
                      metric = v;
                      unitController.text = _vitalDefaultUnits[v] ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (metric == 'bp') ...[
                  TextField(
                    controller: sysController,
                    decoration: const InputDecoration(labelText: 'Systolic'),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: diaController,
                    decoration: const InputDecoration(labelText: 'Diastolic'),
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(labelText: 'Value'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    List<Map<String, dynamic>> readings;
    if (metric == 'bp') {
      final sys = double.tryParse(sysController.text.trim());
      final dia = double.tryParse(diaController.text.trim());
      if (sys == null || dia == null) return;
      readings = [
        {'metric': 'bp_sys', 'value': sys, 'unit': 'mmHg'},
        {'metric': 'bp_dia', 'value': dia, 'unit': 'mmHg'},
      ];
    } else {
      final value = double.tryParse(valueController.text.trim());
      if (value == null) return;
      readings = [
        {
          'metric': metric,
          'value': value,
          if (unitController.text.trim().isNotEmpty) 'unit': unitController.text.trim(),
        },
      ];
    }

    final auth = context.read<AuthProvider>();
    await _runAddAction(
      () => context.read<SupabaseService>().addVital(
            entryCode: auth.entryCode!,
            botKey: widget.botKey,
            encounterId: widget.encounterId,
            readings: readings,
          ),
      successMessage: 'Vital recorded.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _summary?.encounter.status == 'active';
    // زيارة العيادة مالهاش مفهوم "حجز قسم" أصلًا (مفيش سرير) — الزرار ده
    // يظهر بس لحالات الطوارئ/الراوند.
    final canAdmit = isActive && _summary?.encounter.source != 'clinic';

    return Scaffold(
      appBar: AppBar(
        title: Text(_summary?.patient.name ?? 'Patient Details'),
        actions: _summary == null
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export',
                  onSelected: (v) => v == 'prescription' ? _exportPrescription() : _exportPatientReport(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: ListTile(dense: true, leading: Icon(Icons.description_outlined), title: Text('Full Report')),
                    ),
                    PopupMenuItem(
                      value: 'prescription',
                      child: ListTile(dense: true, leading: Icon(Icons.medication_outlined), title: Text('Prescription (Rx)')),
                    ),
                  ],
                ),
                if (isActive)
                  if (_actionInProgress)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    // شات/مايك وكاميرا مخصّصين لنفس المريض ده — أول ما تدوس
                    // عليهم إنت أصلاً جوه كارته، فمفيش أي حاجة تتقال محتاجة
                    // توضيح مين المريض.
                    IconButton(
                      icon: const Icon(Icons.mic_none_outlined),
                      tooltip: 'Record voice or type a note',
                      onPressed: _openPatientChat,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      tooltip: 'Add photo (labs, imaging, wound)',
                      onPressed: _actionInProgress ? null : _showAddPhotoMenu,
                    ),
                    if (canAdmit)
                      IconButton(
                        icon: const Icon(Icons.meeting_room_outlined),
                        tooltip: 'Admit to unit',
                        onPressed: _showAdmitDialog,
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: _summary?.encounter.source == 'clinic' ? 'Close Visit' : 'Discharge',
                      onPressed: _confirmDischarge,
                    ),
                  ],
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _load();
                    // اللستات القابلة للطي بتاعت الأقسام lazy-loaded بتتحدّث
                    // بس لو كانت اتفتحت قبل كده (مفيش داعي نحمّل حاجة الطبيب
                    // ماشافهاش أصلاً).
                    if (_vitalsHistory != null) await _loadVitalsHistory();
                    if (_prescriptionHistory != null) await _loadPrescriptionHistory();
                    if (_historyNotes != null) await _loadNotesByKind('history', (v) => _historyNotes = v);
                    if (_alertsNotes != null) await _loadNotesByKind('health_education', (v) => _alertsNotes = v);
                    if (_treatmentPlanNotes != null) {
                      await _loadNotesByKind('treatment_plan', (v) => _treatmentPlanNotes = v);
                    }
                    if (_resultsNotes != null) await _loadNotesByKind('result', (v) => _resultsNotes = v);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _headerCard(theme),
                      const SizedBox(height: 4),

                      CollapsibleSection(
                        title: 'Vitals',
                        onAdd: isActive ? _showAddVitalDialog : null,
                        onExpand: _loadVitalsHistory,
                        child: VitalsHistoryView(
                          readings: _vitalsHistory ?? const [],
                          encounterOpenedAt: _summary!.encounter.openedAt,
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Orders',
                        count: _summary!.openOrders.length,
                        initiallyExpanded: true,
                        onAdd: isActive ? _showAddOrderDialog : null,
                        child: Column(
                          children: [
                            if (_summary!.openOrders.isEmpty) _emptyHint('No orders yet'),
                            ..._summary!.openOrders.map((o) => _orderTile(o, theme)),
                          ],
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Lab & Imaging Results',
                        onAdd: isActive ? _showAddResultDialog : null,
                        onExpand: () => _loadNotesByKind('result', (v) => _resultsNotes = v),
                        child: NoteHistoryListView(
                          notes: _resultsNotes ?? const [],
                          emptyHint: 'No results recorded yet',
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Prescription',
                        onAdd: isActive ? _showAddPrescriptionDialog : null,
                        onExpand: _loadPrescriptionHistory,
                        child: MedicationHistoryListView(medications: _prescriptionHistory ?? const []),
                      ),

                      CollapsibleSection(
                        title: 'Treatment Plan',
                        onAdd: isActive
                            ? () => _showKindNoteDialog(
                                  title: 'Add Treatment Plan',
                                  hint: 'Plan',
                                  kind: 'treatment_plan',
                                  assign: (v) => _treatmentPlanNotes = v,
                                )
                            : null,
                        onExpand: () => _loadNotesByKind('treatment_plan', (v) => _treatmentPlanNotes = v),
                        child: NoteHistoryListView(
                          notes: _treatmentPlanNotes ?? const [],
                          emptyHint: 'No treatment plan yet',
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Alerts & Patient Instructions',
                        onAdd: isActive
                            ? () => _showKindNoteDialog(
                                  title: 'Add Instruction',
                                  hint: 'e.g. Boiled food only for 3 days',
                                  kind: 'health_education',
                                  assign: (v) => _alertsNotes = v,
                                )
                            : null,
                        onExpand: () => _loadNotesByKind('health_education', (v) => _alertsNotes = v),
                        child: NoteHistoryListView(
                          notes: _alertsNotes ?? const [],
                          emptyHint: 'No instructions yet',
                        ),
                      ),

                      CollapsibleSection(
                        title: 'History',
                        onAdd: isActive
                            ? () => _showKindNoteDialog(
                                  title: 'Add to History',
                                  hint: 'History',
                                  kind: 'history',
                                  assign: (v) => _historyNotes = v,
                                )
                            : null,
                        onExpand: () => _loadNotesByKind('history', (v) => _historyNotes = v),
                        child: NoteHistoryListView(
                          notes: _historyNotes ?? const [],
                          emptyHint: 'No history recorded yet',
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Commitments',
                        count: _summary!.openCommitments.length,
                        initiallyExpanded: true,
                        onAdd: isActive ? _showAddFollowUpDialog : null,
                        child: Column(
                          children: [
                            if (_summary!.openCommitments.isEmpty) _emptyHint('No open commitments'),
                            ..._summary!.openCommitments.map((c) => _commitmentTile(c, theme)),
                          ],
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Complications',
                        count: _summary!.openComplications.length,
                        initiallyExpanded: true,
                        onAdd: isActive ? _showAddComplicationDialog : null,
                        child: Column(
                          children: [
                            if (_summary!.openComplications.isEmpty) _emptyHint('No open complications'),
                            ..._summary!.openComplications.map(
                              (c) => ListTile(
                                leading: const Icon(Icons.warning_amber, color: AppTheme.accentOrange, size: 20),
                                title: Text(c.description),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Notes',
                        initiallyExpanded: true,
                        onAdd: isActive ? _showAddNoteDialog : null,
                        child: Column(
                          children: [
                            if (_generalNotes.isEmpty) _emptyHint('No notes yet'),
                            ..._generalNotes.map(
                              (n) => ListTile(
                                leading: const Icon(Icons.note_outlined, size: 20),
                                title: Text(n.body),
                                subtitle: Text(n.kind),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      CollapsibleSection(
                        title: 'Attachments',
                        count: _summary!.attachments.length,
                        initiallyExpanded: true,
                        onAdd: isActive ? _showAddPhotoMenu : null,
                        child: Column(
                          children: [
                            if (_summary!.attachments.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _actionInProgress ? null : _saveAttachmentsToGallery,
                                  icon: const Icon(Icons.save_alt, size: 18),
                                  label: const Text('Save to gallery'),
                                ),
                              ),
                            if (_summary!.attachments.isEmpty) _emptyHint('No attachments yet'),
                            _attachmentsGrid(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// ملاحظات القسم العام (complaint/exam/diagnosis) بس — history/
  /// health_education/treatment_plan/result بقى ليهم أقسامهم المخصصة، فمبتظهرش
  /// هنا تاني.
  List<NoteInfo> get _generalNotes {
    const dedicatedKinds = {'history', 'health_education', 'treatment_plan', 'result'};
    return _summary!.recentNotes.where((n) => !dedicatedKinds.contains(n.kind)).toList();
  }

  Widget _headerCard(ThemeData theme) {
    final p = _summary!.patient;
    final e = _summary!.encounter;
    final ageLine = p.birthYear != null ? '${DateTime.now().year - p.birthYear!} yrs' : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    [
                      'MRN ${p.mrn}',
                      if (e.handle != null) '#${cleanTicket(e.handle!)}',
                      if (ageLine != null) ageLine,
                      if (p.sex != null) p.sex == 'm' ? 'Male' : 'Female',
                      if (e.unit != null) e.unit!,
                    ].join(' · '),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                if (e.handle != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => copyToClipboard(context, cleanTicket(e.handle!), label: 'Ticket copied'),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 16, color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
            if (e.attending != null) ...[
              const SizedBox(height: 4),
              Text('Attending: ${e.attending}', style: theme.textTheme.bodySmall),
            ],
            if (p.allergies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppTheme.criticalRed, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Allergies: ${p.allergies.join(', ')}',
                      style: const TextStyle(color: AppTheme.criticalRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (p.chronicConditions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Chronic: ${p.chronicConditions.join(', ')}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }

  static final _vitalDateFormat = DateFormat('dd-MM-yyyy, hh:mm a');

  /// بيبني سطر زي "Ordered by Dr. X at 04-08-2026, 01:18 PM" — بيتجاهل الاسم
  /// أو الوقت لو مش موجود (بيانات قديمة قبل migration 019 مثلًا).
  String _orderActionLine(String verb, String? who, DateTime? at) {
    final parts = [verb];
    if (who != null && who.isNotEmpty) parts.addAll(['by', who]);
    if (at != null) parts.addAll(['at', _vitalDateFormat.format(at)]);
    return parts.join(' ');
  }

  Widget _orderTile(OrderInfo o, ThemeData theme) {
    final subtitleLines = [
      o.category,
      _orderActionLine('Ordered', o.orderedBy, o.orderedAt),
      if (o.isCompleted) _orderActionLine('Done', o.resolvedBy, o.resolvedAt),
      if (o.isCancelled) _orderActionLine('Cancelled', o.resolvedBy, o.resolvedAt),
    ];

    // إجراء اتجاه واحد بس: pending تقدر تعملها done أو تلغيها؛ لما تتعمل done
    // أو تتلغي تبقى نهائية من الواجهة — مفيش تراجع باللمسة، ومفيش الاتنين
    // (done وcancel) لنفس الأوردر أبدًا (الباك إند بيمنع cancel إلا من pending).
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: o.isPending
            ? IconButton(
                icon: const Icon(Icons.radio_button_unchecked, color: AppTheme.primaryBlue),
                onPressed: _actionInProgress ? null : () => _completeOrder(o),
                tooltip: 'Tap to mark done',
              )
            : Icon(
                o.isCompleted ? Icons.check_circle : Icons.block,
                color: o.isCompleted ? AppTheme.successGreen : Colors.grey,
              ),
        title: Text(
          o.name,
          style: o.isCancelled
              ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
              : null,
        ),
        subtitle: Text(subtitleLines.join('\n')),
        isThreeLine: subtitleLines.length > 2,
        trailing: o.isPending
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.criticalRed),
                tooltip: 'Cancel order',
                onPressed: _actionInProgress ? null : () => _cancelOrder(o),
              )
            : null,
        onTap: o.isPending && !_actionInProgress ? () => _completeOrder(o) : null,
      ),
    );
  }

  Widget _commitmentTile(Commitment c, ThemeData theme) {
    final due = c.dueAt != null ? DateFormat('MMM d, HH:mm').format(c.dueAt!) : 'No due time';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          c.isOverdue ? Icons.schedule : Icons.task_alt,
          color: c.isOverdue ? AppTheme.criticalRed : AppTheme.successGreen,
        ),
        title: Text(c.text),
        subtitle: Text(
          'Due: $due',
          style: TextStyle(color: c.isOverdue ? AppTheme.criticalRed : theme.hintColor),
        ),
      ),
    );
  }

  Widget _attachmentsGrid(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _summary!.attachments
          .map((a) => ZoomableAttachmentImage(storagePath: a.storagePath, size: 100))
          .toList(),
    );
  }
}
