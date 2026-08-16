import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/encounter.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../utils/error_utils.dart';
import '../utils/report_formatter.dart';
import '../utils/report_pdf.dart';
import '../widgets/encounter_card.dart';
import 'patient_detail_screen.dart';

/// أرشيف المرضى المخرّجين — منفصل عن البورد النشط. مخزن قابل للبحث والفلترة
/// بمدى تاريخي (تاريخ الخروج) والتصدير، مش مجرد قائمة. الفلترة بالتاريخ بتتم
/// على السيرفر (migration 030: p_from/p_to) عشان ميحمّلش الكل، ولو الميجريشن
/// لسه مش متطبّق بيرجع تلقائيًا لتحميل الكل + فلترة client-side.
class DischargedListScreen extends StatefulWidget {
  const DischargedListScreen({super.key, required this.title, required this.botKey});

  final String title;
  final String botKey;

  @override
  State<DischargedListScreen> createState() => _DischargedListScreenState();
}

class _DischargedListScreenState extends State<DischargedListScreen> {
  final _searchController = TextEditingController();
  final _shortDate = DateFormat('MMM d');
  final _longDate = DateFormat('MMM d, yyyy');

  String _query = '';
  late DateTime _from;
  DateTime? _to;
  bool _serverDated = false;
  bool _loading = true;
  String? _error;
  bool _isExporting = false;
  List<Encounter> _all = [];

  @override
  void initState() {
    super.initState();
    _from = _defaultFrom();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _defaultFrom() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(const Duration(days: 30));
  }

  DateTime? _toEndOfDay() =>
      _to == null ? null : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final supabase = context.read<SupabaseService>();
    try {
      final list = await supabase.encounterList(
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        filter: EncounterFilter.discharged,
        from: _from,
        to: _toEndOfDay(),
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _serverDated = true;
        _loading = false;
      });
    } catch (_) {
      // Backend without p_from/p_to (migration 030 not applied yet) → load all
      // and apply the date range client-side instead.
      try {
        final list = await supabase.encounterList(
          entryCode: auth.entryCode!,
          botKey: widget.botKey,
          filter: EncounterFilter.discharged,
        );
        if (!mounted) return;
        setState(() {
          _all = list;
          _serverDated = false;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = describeError(e);
          _loading = false;
        });
      }
    }
  }

  List<Encounter> _visible() {
    final q = _query.trim().toLowerCase();
    Iterable<Encounter> list = _all;
    if (!_serverDated) {
      final end = _toEndOfDay();
      list = list.where((e) {
        final d = e.dischargedAt;
        if (d == null) return false;
        if (d.isBefore(_from)) return false;
        if (end != null && d.isAfter(end)) return false;
        return true;
      });
    }
    if (q.isNotEmpty) {
      list = list.where((e) =>
          e.patientName.toLowerCase().contains(q) ||
          e.mrn.toLowerCase().contains(q) ||
          (e.handle?.toLowerCase().contains(q) ?? false));
    }
    final result = list.toList();
    result.sort((a, b) =>
        (b.dischargedAt ?? DateTime(0)).compareTo(a.dischargedAt ?? DateTime(0)));
    return result;
  }

  String _rangeLabel() {
    final fromS = _longDate.format(_from);
    final toS = _to != null ? _longDate.format(_to!) : 'now';
    return '$fromS → $toS';
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(now.year - 3),
      lastDate: _to ?? now,
    );
    if (picked != null) {
      setState(() => _from = DateTime(picked.year, picked.month, picked.day));
      _load();
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? now,
      firstDate: _from,
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _to = DateTime(picked.year, picked.month, picked.day));
      _load();
    }
  }

  void _reset() {
    _searchController.clear();
    setState(() {
      _query = '';
      _from = _defaultFrom();
      _to = null;
    });
    _load();
  }

  Future<void> _export(List<Encounter> rows, {required bool asPdf}) async {
    if (_isExporting || rows.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      final scope =
          'Discharged · ${_rangeLabel()}${_query.trim().isNotEmpty ? ' · "${_query.trim()}"' : ''}';
      final subject = '${widget.title} — $scope';
      final report = await formatBoardReport(
        supabaseService: supabase,
        entryCode: auth.entryCode!,
        botKey: widget.botKey,
        encounters: rows,
        title: subject,
      );
      if (!mounted) return;
      if (asPdf) {
        await shareReportPdf(subject: subject, body: report, filename: 'discharged-report.pdf');
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

  @override
  Widget build(BuildContext context) {
    final rows = _visible();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (rows.isEmpty)
            const IconButton(
              icon: Icon(Icons.ios_share),
              tooltip: 'Export',
              onPressed: null,
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onSelected: (v) => _export(rows, asPdf: v == 'pdf'),
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, MRN, or ticket...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text('From: ${_shortDate.format(_from)}'),
                  onPressed: _pickFrom,
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_available, size: 16),
                  label: Text('To: ${_to != null ? _shortDate.format(_to!) : 'Now'}'),
                  onPressed: _pickTo,
                ),
                ActionChip(
                  avatar: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(
              _loading ? 'Loading…' : '${rows.length} record${rows.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
          Expanded(child: _buildBody(rows)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Encounter> rows) {
    if (_loading && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                _query.isNotEmpty
                    ? 'No matches for "$_query"'
                    : 'No discharged cases in this range.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final e = rows[index];
          return EncounterCard(
            encounter: e,
            activeFilter: EncounterFilter.discharged,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PatientDetailScreen(
                  encounterId: e.encounterId,
                  botKey: widget.botKey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
