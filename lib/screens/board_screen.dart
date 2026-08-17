import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/unit_info.dart';
import '../providers/auth_provider.dart';
import '../providers/board_provider.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';
import '../utils/report_formatter.dart';
import '../utils/report_pdf.dart';
import '../widgets/encounter_card.dart';
import '../widgets/filter_chips.dart';
import 'discharged_list_screen.dart';
import 'patient_detail_screen.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({
    super.key,
    required this.title,
    required this.provider,
    required this.botKey,
  });

  final String title;
  final BoardProvider provider;
  final String botKey;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BoardProvider>.value(
      value: provider,
      child: _BoardContent(title: title, botKey: botKey),
    );
  }
}

class _BoardContent extends StatefulWidget {
  const _BoardContent({required this.title, required this.botKey});

  final String title;
  final String botKey;

  @override
  State<_BoardContent> createState() => _BoardContentState();
}

class _BoardContentState extends State<_BoardContent> {
  final _searchController = TextEditingController();
  bool _isExporting = false;
  bool _isAddingPatient = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// المريض بيتسجّل باسمه وتذكرته بس (وقسمه لو التاب ده الراوند) — كل حاجة
  /// تانية فاضية في الكارت وتتضاف بعدين من جوّه. مفيش كارت مراجعة هنا: الطبيب
  /// هو نفسه اللي كاتب القيم يدويًا، فمفيش تفسير AI ممكن يغلط فيه.
  Future<void> _showAddPatientDialog(BoardProvider board) async {
    final isRound = widget.botKey == 'round';

    // القسم معلومة أساسية للراوند بالذات — بنجيب قائمة الأقسام الحقيقية
    // بتاعة المستشفى قبل ما نفتح الفورم، عشان تبقى جاهزة كـ dropdown.
    List<UnitInfo> units = const [];
    if (isRound) {
      try {
        final auth = context.read<AuthProvider>();
        final supabase = context.read<SupabaseService>();
        units = await supabase.listUnits(entryCode: auth.entryCode!, botKey: widget.botKey);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeError(e)), backgroundColor: Colors.red),
          );
        }
        return;
      }
      if (!mounted) return;
    }

    final nameController = TextEditingController();
    final ticketController = TextEditingController();
    UnitInfo? selectedUnit;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Patient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ticketController,
                decoration: const InputDecoration(labelText: 'Ticket number'),
                keyboardType: TextInputType.number,
              ),
              if (isRound) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<UnitInfo>(
                  initialValue: selectedUnit,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedUnit = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    final ticket = ticketController.text.trim();
    if (confirmed != true || name.isEmpty || ticket.isEmpty || !mounted) return;
    if (isRound && selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a department.')),
      );
      return;
    }

    setState(() => _isAddingPatient = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      // العيادة مصدرها 'clinic' صريح. الراوند بيتسجّل كـ 'referral' (مريض
      // بيدخل الراوند مباشرة، مش جاي متسجّل من الطوارئ أصلًا). الطوارئ مبعتش
      // p_source خالص فبترجع للافتراضي 'ed' في قاعدة البيانات.
      final source = widget.botKey == 'clinic'
          ? 'clinic'
          : widget.botKey == 'round'
              ? 'referral'
              : null;
      final encounterId = await supabase.createPatient(
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        name: name,
        ticket: ticket,
        source: source,
      );
      // الراوند: تحجز القسم فورًا بعد التسجيل، عشان المريض يبان في تاب
      // الراوند على طول بدل ما يفضل شايل في الطوارئ لحد الحجز.
      if (isRound && selectedUnit != null) {
        await supabase.admitToUnit(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          encounterId: encounterId,
          unit: selectedUnit!,
        );
      }
      if (!mounted) return;
      board.loadEncounters();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PatientDetailScreen(encounterId: encounterId, botKey: widget.botKey),
        ),
      );
      board.loadEncounters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingPatient = false);
    }
  }

  Future<void> _exportBoard(BoardProvider board, {required bool asPdf}) async {
    if (_isExporting || board.encounters.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      final filterLabel = board.filter.label + (board.filterDate != null ? ' — ${_dateLabel(board.filterDate!)}' : '');
      final subject = '${widget.title} — $filterLabel';
      final report = await formatBoardReport(
        supabaseService: supabase,
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        encounters: board.encounters,
        title: subject,
      );
      if (!mounted) return;
      if (asPdf) {
        await shareReportPdf(subject: subject, body: report, filename: '${widget.botKey}-report.pdf');
      } else {
        await Share.share(report, subject: subject);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _pickDate(BoardProvider board) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: board.filterDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      board.setCustomDate(picked);
    }
  }

  /// فلتر القسم في تاب الراوند — بيجيب أقسام المؤسسة من app_list_units وبيعرضها
  /// في bottom sheet مع خيار "كل الأقسام"، والفلترة نفسها client-side على البورد.
  Future<void> _pickDepartment(BoardProvider board) async {
    final auth = context.read<AuthProvider>();
    final supabase = context.read<SupabaseService>();
    List<UnitInfo> units;
    try {
      units = await supabase.listUnits(entryCode: auth.entryCode!, botKey: widget.botKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('All Departments'),
              trailing: board.unitFilter == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, '__all__'),
            ),
            const Divider(height: 1),
            for (final u in units)
              ListTile(
                leading: const Icon(Icons.apartment),
                title: Text(u.name),
                trailing: board.unitFilter == u.name ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, u.name),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return; // dismissed without choosing
    board.setUnitFilter(selected == '__all__' ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onSelected: (v) => _exportBoard(board, asPdf: v == 'pdf'),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(dense: true, leading: Icon(Icons.picture_as_pdf), title: Text('Export PDF')),
                ),
                PopupMenuItem(
                  value: 'text',
                  child: ListTile(dense: true, leading: Icon(Icons.notes), title: Text('Share as text')),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Discharged',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DischargedListScreen(
                  title: widget.botKey == 'round' ? 'Discharged from Rounds' : 'Discharged from ED',
                  botKey: widget.botKey,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: board.loadEncounters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: board.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search by patient name, MRN, or ticket...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: board.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          board.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          FilterChips(selected: board.filter, onSelected: board.setFilter),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Today'),
                  avatar: Icon(Icons.today, size: 16, color: board.isTodayFilter ? Colors.white : null),
                  selected: board.isTodayFilter,
                  onSelected: (_) => board.toggleToday(),
                  showCheckmark: false,
                ),
                if (board.filterDate != null && !board.isTodayFilter)
                  InputChip(
                    label: Text(_dateLabel(board.filterDate!)),
                    avatar: const Icon(Icons.event, size: 16),
                    onPressed: () => _pickDate(board),
                    onDeleted: board.clearDateFilter,
                  )
                else
                  ActionChip(
                    label: const Text('Pick date'),
                    avatar: const Icon(Icons.calendar_month, size: 16),
                    onPressed: () => _pickDate(board),
                  ),
                if (widget.botKey == 'round')
                  board.unitFilter != null
                      ? InputChip(
                          label: Text(board.unitFilter!),
                          avatar: const Icon(Icons.apartment, size: 16),
                          onPressed: () => _pickDepartment(board),
                          onDeleted: () => board.setUnitFilter(null),
                        )
                      : ActionChip(
                          label: const Text('Department'),
                          avatar: const Icon(Icons.apartment, size: 16),
                          onPressed: () => _pickDepartment(board),
                        ),
              ],
            ),
          ),
          if (board.isLoading && board.encounters.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (board.error != null && board.encounters.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(board.error!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: board.loadEncounters, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (board.encounters.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  board.searchQuery.isNotEmpty
                      ? 'No matches for "${board.searchQuery}"'
                      : board.filterDate != null
                          ? 'No cases opened on ${_dateLabel(board.filterDate!)}'
                          : 'No cases match this filter',
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: board.loadEncounters,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: board.encounters.length,
                  itemBuilder: (context, index) {
                    final e = board.encounters[index];
                    return EncounterCard(
                      encounter: e,
                      activeFilter: board.filter,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PatientDetailScreen(
                              encounterId: e.encounterId,
                              botKey: widget.botKey,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isAddingPatient ? null : () => _showAddPatientDialog(board),
        tooltip: 'New patient',
        child: _isAddingPatient
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
      ),
    );
  }
}
