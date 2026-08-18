import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nurse_task.dart';
import '../providers/auth_provider.dart';
import '../providers/nurse_task_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

const _categoryLabel = {
  'lab': 'Lab',
  'imaging': 'Imaging',
  'consult': 'Consult',
  'procedure': 'Procedure',
  'general': 'General',
  'vitals': 'Vitals',
};

const _statusLabel = {
  'assigned': 'New',
  'accepted': 'Accepted',
  'in_progress': 'In Progress',
  'completed': 'Completed',
};

Color _statusColor(String status) {
  switch (status) {
    case 'assigned':
      return AppTheme.accentOrange;
    case 'accepted':
      return AppTheme.primaryBlue;
    case 'in_progress':
      return AppTheme.primaryBlueLight;
    case 'completed':
      return AppTheme.successGreen;
    default:
      return Colors.grey;
  }
}

class NurseTaskListScreen extends StatelessWidget {
  const NurseTaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Consumer<NurseTaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.tasks.isEmpty) {
            return RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [const SizedBox(height: 120), Center(child: Text(provider.error!))],
              ),
            );
          }
          if (provider.tasks.isEmpty) {
            return RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('No tasks assigned to you right now', style: TextStyle(color: Theme.of(context).hintColor))),
                ],
              ),
            );
          }

          final groups = <String, List<NurseTask>>{'assigned': [], 'accepted': [], 'in_progress': [], 'completed': []};
          for (final t in provider.tasks) {
            (groups[t.taskStatus] ??= []).add(t);
          }

          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final status in ['assigned', 'accepted', 'in_progress', 'completed'])
                  if (groups[status]!.isNotEmpty) ...[
                    _sectionHeader(_statusLabel[status]!, groups[status]!.length),
                    for (final task in groups[status]!) _taskTile(context, task),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        '$label ($count)',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .04, color: Colors.grey),
      ),
    );
  }

  Widget _taskTile(BuildContext context, NurseTask task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(task.taskStatus).withValues(alpha: 0.12),
          child: Icon(Icons.assignment_outlined, color: _statusColor(task.taskStatus), size: 20),
        ),
        title: Text(task.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            _categoryLabel[task.category] ?? task.category,
            task.name,
            if (task.unit != null) task.unit!,
            if (task.handle != null) task.handle!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(task.taskStatus).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _statusLabel[task.taskStatus] ?? task.taskStatus,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(task.taskStatus)),
          ),
        ),
        onTap: () => _openTaskSheet(context, task),
      ),
    );
  }

  void _openTaskSheet(BuildContext context, NurseTask task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TaskDetailSheet(task: task),
    );
  }
}

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({required this.task});
  final NurseTask task;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  final _noteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function(SupabaseService, String) call) async {
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      final supabase = context.read<SupabaseService>();
      await call(supabase, auth.entryCode!);
      if (mounted) {
        Navigator.pop(context);
        context.read<NurseTaskProvider>().load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.patientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (task.unit != null || task.handle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text([task.unit, task.handle].whereType<String>().join(' · '), style: TextStyle(color: Theme.of(context).hintColor)),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryLabel[task.category] ?? task.category, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(task.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (task.isAssigned)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _act((s, code) => s.nurseTaskAccept(entryCode: code, orderId: task.orderId)),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
              ),
            )
          else if (task.isAccepted)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _act((s, code) => s.nurseTaskStart(entryCode: code, orderId: task.orderId)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            )
          else if (task.isInProgress) ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Result note (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. BP 120/80, done',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _act((s, code) => s.nurseTaskComplete(entryCode: code, orderId: task.orderId, resultNote: _noteController.text)),
                icon: const Icon(Icons.done_all),
                label: const Text('Save & Complete'),
              ),
            ),
          ] else
            Text('Completed', style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
