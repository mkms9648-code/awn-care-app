import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/portal_escalation.dart';
import '../providers/portal_inbox_provider.dart';
import '../theme/app_theme.dart';
import 'portal_thread_screen.dart';

/// صندوق وارد التصعيدات (تاب المساعد) — الحالات اللي الـ AI مش قادر يردّ
/// عليها بأمان (عرض جديد، مضاعفة محتملة...) وبتحتاج مراجعة الطبيب. نفس شكل
/// BoardScreen (فلتر أعلى + لستة قابلة للسحب للتحديث) لكن مبني على
/// PortalInboxProvider بدل BoardProvider.
class PortalInboxScreen extends StatelessWidget {
  const PortalInboxScreen({super.key, required this.provider});

  final PortalInboxProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PortalInboxProvider>.value(
      value: provider,
      child: const _PortalInboxContent(),
    );
  }
}

class _PortalInboxContent extends StatelessWidget {
  const _PortalInboxContent();

  static const _statusFilters = [
    ('open', 'Open'),
    ('replied', 'Replied'),
    ('resolved', 'Resolved'),
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppTheme.criticalRed;
      case 'replied':
        return AppTheme.accentOrange;
      case 'resolved':
        return AppTheme.successGreen;
      default:
        return Colors.grey;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<PortalInboxProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: inbox.loadInbox,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in _statusFilters)
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: inbox.status == f.$1,
                    onSelected: (_) => inbox.setStatus(f.$1),
                  ),
              ],
            ),
          ),
          if (inbox.isLoading && inbox.escalations.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (inbox.error != null && inbox.escalations.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(inbox.error!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: inbox.loadInbox, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (inbox.escalations.isEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: inbox.loadInbox,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Text(
                        inbox.status == 'open' ? 'No open escalations.' : 'Nothing here yet.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: inbox.loadInbox,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: inbox.escalations.length,
                  itemBuilder: (context, index) {
                    final e = inbox.escalations[index];
                    return _EscalationCard(
                      escalation: e,
                      statusColor: _statusColor(e.status),
                      relativeTime: _relativeTime(e.createdAt),
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => PortalThreadScreen(escalation: e),
                              ),
                            )
                            .then((_) => inbox.loadInbox());
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({
    required this.escalation,
    required this.statusColor,
    required this.relativeTime,
    required this.onTap,
  });

  final PortalEscalation escalation;
  final Color statusColor;
  final String relativeTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = escalation;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.patientName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (e.ticket != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '#${e.ticket}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (e.reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  e.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(relativeTime, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.status[0].toUpperCase() + e.status.substring(1),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
