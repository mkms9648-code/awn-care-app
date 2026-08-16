import 'package:flutter/material.dart';

import '../models/encounter.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_utils.dart';
import '../utils/ticket_utils.dart';

class EncounterCard extends StatelessWidget {
  const EncounterCard({
    super.key,
    required this.encounter,
    required this.activeFilter,
    this.onTap,
  });

  final Encounter encounter;
  final EncounterFilter activeFilter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = encounter;

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
                  if (e.handle != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '#${cleanTicket(e.handle!)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => copyToClipboard(context, cleanTicket(e.handle!), label: 'Ticket copied'),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy, size: 15, color: theme.hintColor),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'MRN ${e.mrn}${e.unit != null ? ' · ${e.unit}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              if (e.attending != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Dr. ${e.attending}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    e.dischargedAt != null
                        ? 'Discharged ${_relativeDays(e.dischargedAt!)}'
                        : '${e.openDays} day${e.openDays == 1 ? '' : 's'} open',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (activeFilter.hasDetail && e.detailCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${activeFilter.label} (${e.detailCount})',
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  String _relativeDays(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }
}
