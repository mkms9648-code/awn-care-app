import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan_usage.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PlanUsage? _usage;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final service = context.read<SupabaseService>();
    try {
      final results = await Future.wait([
        service.planUsage(entryCode: auth.entryCode!),
        service.notificationsList(entryCode: auth.entryCode!),
      ]);
      if (mounted) {
        setState(() {
          _usage = results[0] as PlanUsage;
          _unreadCount = (results[1] as List).where((n) => n.isUnread == true).length;
        });
      }
    } catch (_) {
      // بيانات ثانوية — لو فشلت مفيش داعي توقف باقي شاشة البروفايل.
    }
  }

  String _moduleLabel(String key) {
    switch (key) {
      case 'ed':
        return 'Emergency';
      case 'round':
        return 'Rounds';
      case 'clinic':
        return 'Clinic';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile!;
    final sub = profile.subscription;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$_unreadCount'),
              isLabelVisible: _unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    child: Text(
                      _initials(profile.name),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(profile.role, style: theme.textTheme.bodyMedium),
                        if (profile.specialty != null)
                          Text(profile.specialty!, style: TextStyle(color: theme.hintColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Physician Details', theme),
          _infoTile(Icons.badge_outlined, 'License Number', profile.licenseNumber ?? 'Not set'),
          _infoTile(Icons.local_hospital_outlined, 'Hospital', profile.hospitalName ?? 'Not set'),
          const SizedBox(height: 16),
          _sectionHeader('Subscription', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sub.planName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (sub.isActive ? AppTheme.successGreen : AppTheme.criticalRed)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.statusLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sub.isActive ? AppTheme.successGreen : AppTheme.criticalRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Enabled Features', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sub.enabledFeatures.map((f) {
                      return Chip(
                        label: Text(_featureLabel(f), style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          if (_usage != null && _usage!.modules.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader('Plan Usage', theme),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 16, color: theme.hintColor),
                        const SizedBox(width: 6),
                        Text(
                          '${_usage!.daysUntilRenewal} days until renewal',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final m in _usage!.modules) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(_moduleLabel(m.moduleKey), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '${m.used} / ${m.maxPerPeriod}',
                            style: TextStyle(
                              color: m.fraction >= 0.9 ? AppTheme.criticalRed : theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: m.fraction,
                          minHeight: 8,
                          backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation(
                            m.fraction >= 0.9 ? AppTheme.criticalRed : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await auth.logout();
              }
            },
            icon: const Icon(Icons.logout, color: AppTheme.criticalRed),
            label: const Text('Log Out', style: TextStyle(color: AppTheme.criticalRed)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.criticalRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.hintColor,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryBlue),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _featureLabel(String key) {
    return key.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
