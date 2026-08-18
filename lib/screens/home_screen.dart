import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/board_provider.dart';
import '../providers/portal_inbox_provider.dart';
import '../services/supabase_service.dart';
import 'analytics_screen.dart';
import 'board_screen.dart';
import 'portal_inbox_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NavTab {
  const _NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  BoardProvider? _edBoardProvider;
  BoardProvider? _roundsBoardProvider;
  BoardProvider? _clinicBoardProvider;
  AnalyticsProvider? _analyticsProvider;
  PortalInboxProvider? _portalInboxProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Providers are created once when dependencies are first available.
    if (!_initialized) {
      final auth = context.read<AuthProvider>();
      final entryCode = auth.entryCode!;
      final workspaceId = auth.profile?.workspaceId;
      final features = auth.profile?.enabledFeatures ?? const <String>[];
      final supabase = context.read<SupabaseService>();

      // كل تاب/بوت بيظهر بس لو الدكتور فعليًا مشترك فيه — لا داعي نعرض تاب
      // مفيهوش حاجة أو هيرجع خطأ صلاحيات لمجرد إنه مش جزء من اشتراكه.
      final hasEd = features.contains('ed_module');
      final hasRound = features.contains('round_module');
      final hasClinic = features.contains('clinic_module');
      final hasPortal = features.contains('patient_portal_module');

      if (hasEd || hasRound || hasClinic) {
        _analyticsProvider = AnalyticsProvider(
          supabaseService: supabase,
          entryCode: entryCode,
          hasHospital: hasEd || hasRound,
          hasClinic: hasClinic,
          hospitalBotKey: hasEd ? 'ed' : 'round',
        );
      }

      if (hasEd) {
        _edBoardProvider = BoardProvider(
          supabaseService: supabase,
          entryCode: entryCode,
          botKey: 'ed',
          workspaceId: workspaceId,
        );
      }

      if (hasRound) {
        _roundsBoardProvider = BoardProvider(
          supabaseService: supabase,
          entryCode: entryCode,
          botKey: 'round',
          workspaceId: workspaceId,
        );
      }

      if (hasClinic) {
        _clinicBoardProvider = BoardProvider(
          supabaseService: supabase,
          entryCode: entryCode,
          botKey: 'clinic',
          workspaceId: workspaceId,
        );
      }

      if (hasPortal) {
        _portalInboxProvider = PortalInboxProvider(
          supabaseService: supabase,
          entryCode: entryCode,
        );
      }

      _initialized = true;
    }
  }

  bool _initialized = false;

  @override
  void dispose() {
    _edBoardProvider?.dispose();
    _roundsBoardProvider?.dispose();
    _clinicBoardProvider?.dispose();
    _analyticsProvider?.dispose();
    _portalInboxProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = <_NavTab>[
      if (_edBoardProvider != null)
        _NavTab(
          icon: Icons.emergency_outlined,
          selectedIcon: Icons.emergency,
          label: 'ED',
          screen: BoardScreen(
            title: 'Emergency Department',
            provider: _edBoardProvider!,
            botKey: 'ed',
          ),
        ),
      if (_roundsBoardProvider != null)
        _NavTab(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          label: 'Rounds',
          screen: BoardScreen(
            title: 'Rounds',
            provider: _roundsBoardProvider!,
            botKey: 'round',
          ),
        ),
      if (_clinicBoardProvider != null)
        _NavTab(
          icon: Icons.apartment_outlined,
          selectedIcon: Icons.apartment,
          label: 'Clinic',
          screen: BoardScreen(
            title: 'Clinic',
            provider: _clinicBoardProvider!,
            botKey: 'clinic',
          ),
        ),
      if (_portalInboxProvider != null)
        _NavTab(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Assistant',
          screen: PortalInboxScreen(provider: _portalInboxProvider!),
        ),
      if (_analyticsProvider != null)
        _NavTab(
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          label: 'Analytics',
          screen: ChangeNotifierProvider<AnalyticsProvider>.value(
            value: _analyticsProvider!,
            child: const AnalyticsScreen(),
          ),
        ),
      const _NavTab(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        screen: ProfileScreen(),
      ),
    ];

    final currentIndex = _currentIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: [for (final t in tabs) t.screen]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
