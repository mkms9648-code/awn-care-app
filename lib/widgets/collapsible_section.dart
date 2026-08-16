import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// قسم قابل للطي/الفتح لكارت المريض — عنوان بسهم بيلف لما تدوس عليه، مع
/// أيقونة "+" اختيارية للإضافة اليدوية. لو [onExpand] موجودة، بتتنادى مرة
/// واحدة بس أول ما القسم يتفتح لأول مرة (lazy load) — القسم بيوري مؤشر تحميل
/// لحد ما الداتا توصل.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.onAdd,
    this.initiallyExpanded = false,
    this.onExpand,
  });

  final String title;
  final int? count;
  final Widget child;
  final VoidCallback? onAdd;
  final bool initiallyExpanded;

  /// بتتنادى مرة واحدة بس أول ما القسم يتفتح لأول مرة.
  final Future<void> Function()? onExpand;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;
  bool _loading = false;
  bool _loadedOnce = false;

  Future<void> _toggle() async {
    final expanding = !_expanded;
    setState(() => _expanded = expanding);
    if (expanding && !_loadedOnce && widget.onExpand != null) {
      setState(() => _loading = true);
      try {
        await widget.onExpand!();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      _loadedOnce = true;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_expanded && widget.onExpand != null) {
      _loading = true;
      widget.onExpand!().whenComplete(() {
        _loadedOnce = true;
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.chevron_right, color: theme.hintColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.count != null ? '${widget.title} (${widget.count})' : widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  if (widget.onAdd != null)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 21, color: AppTheme.primaryBlue),
                      tooltip: 'Add',
                      onPressed: widget.onAdd,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: widget.child,
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}
