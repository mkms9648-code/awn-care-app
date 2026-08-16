import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

/// Review card embedded in chat — explicit, editable confirmation before
/// save. While unresolved, every field is a text box the doctor can correct
/// (e.g. a mis-transcribed number) before anything is written to the record.
class ReviewCardWidget extends StatefulWidget {
  const ReviewCardWidget({
    super.key,
    required this.data,
    this.subtitle,
    this.onConfirm,
    this.onReject,
  });

  final ReviewCardData data;
  final String? subtitle;
  final void Function(Map<String, String> editedFields)? onConfirm;
  final VoidCallback? onReject;

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final e in widget.data.fields.entries) e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final isResolved = data.isConfirmed != null;
    final editable = !isResolved && widget.onConfirm != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isResolved
              ? (data.isConfirmed! ? AppTheme.successGreen : theme.dividerColor)
              : AppTheme.accentOrange.withValues(alpha: 0.6),
          width: isResolved ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: isResolved
                      ? (data.isConfirmed! ? AppTheme.successGreen : theme.hintColor)
                      : AppTheme.accentOrange,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(widget.subtitle!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ...data.fields.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: editable
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              e.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controllers[e.key],
                              style: theme.textTheme.bodyMedium,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              e.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(child: Text(e.value, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
              ),
            ),
            if (isResolved) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    data.isConfirmed! ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: data.isConfirmed! ? AppTheme.successGreen : theme.hintColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.isConfirmed! ? 'Confirmed' : 'Cancelled',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: data.isConfirmed! ? AppTheme.successGreen : theme.hintColor,
                    ),
                  ),
                ],
              ),
            ] else if (widget.onConfirm != null && widget.onReject != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onReject,
                      child: Text(data.rejectAction),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => widget.onConfirm!(
                        {for (final k in _controllers.keys) k: _controllers[k]!.text},
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                      child: Text(data.confirmAction, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
