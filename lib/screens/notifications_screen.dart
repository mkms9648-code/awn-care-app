import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

final _dateFmt = DateFormat('dd MMM, h:mm a');

/// أخبار من الإدارة + تنبيهات تلقائية لاقتراب انتهاء حد الباقة — بث لكل
/// مساحة العمل أو رسائل شخصية، الأحدث أولًا.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

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
      final items = await context.read<SupabaseService>().notificationsList(entryCode: auth.entryCode!);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (n.isUnread) {
      final auth = context.read<AuthProvider>();
      unawaited(context.read<SupabaseService>().notificationsMarkRead(entryCode: auth.entryCode!, notificationId: n.id));
      setState(() {
        final i = _items.indexWhere((x) => x.id == n.id);
        if (i != -1) {
          _items[i] = AppNotification(
            id: n.id, title: n.title, body: n.body, kind: n.kind, createdAt: n.createdAt, readAt: DateTime.now(),
          );
        }
      });
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Text(n.body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!)),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text('No notifications yet', style: TextStyle(color: Theme.of(context).hintColor))),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final n = _items[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: (n.kind == 'quota_alert' ? AppTheme.accentOrange : AppTheme.primaryBlue)
                .withValues(alpha: 0.12),
            child: Icon(
              n.kind == 'quota_alert' ? Icons.speed_outlined : Icons.campaign_outlined,
              color: n.kind == 'quota_alert' ? AppTheme.accentOrange : AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          title: Text(n.title, style: TextStyle(fontWeight: n.isUnread ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_dateFmt.format(n.createdAt), style: const TextStyle(fontSize: 11)),
              if (n.isUnread)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                ),
            ],
          ),
          onTap: () => _open(n),
        );
      },
    );
  }
}
