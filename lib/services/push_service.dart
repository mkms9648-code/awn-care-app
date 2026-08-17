import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/portal_escalation.dart';
import '../screens/portal_thread_screen.dart';
import 'supabase_service.dart';

/// Firebase Cloud Messaging wiring for portal escalation alerts — permission
/// request, token registration (app_register_push_token), foreground
/// banners, and deep-linking into [PortalThreadScreen] when the doctor taps
/// a notification (app backgrounded or fully terminated).
///
/// The app has no router/named routes — every push in the codebase navigates
/// with `Navigator.push(MaterialPageRoute(...))` off a `BuildContext`. Since
/// this service reacts to messages that can arrive with no screen currently
/// mounted (app terminated), it needs a [GlobalKey<NavigatorState>] threaded
/// through `MaterialApp.navigatorKey` (added in main.dart) so it can push
/// without one. That key is new to this codebase — flagged for review.
class PushService {
  PushService({required GlobalKey<NavigatorState> navigatorKey}) : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState> _navigatorKey;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  SupabaseService? _supabaseService;
  String? _entryCode;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  /// اتنادى مرة واحدة بس بعد نجاح تسجيل الدخول (AuthProvider عنده entryCode
  /// جاهز وقتها) — بيطلب صلاحية الإشعارات، يسجّل التوكن الحالي، ويراقب أي
  /// تجديد ليه، وبيوصّل حالتين الضغط على الإشعار (خلفية/تطبيق مقفول تمامًا).
  Future<void> init({
    required SupabaseService supabaseService,
    required String entryCode,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _supabaseService = supabaseService;
    _entryCode = entryCode;

    // لو مفيش Firebase project حقيقي متوصّل لسه (راجع
    // google-services.json.PLACEHOLDER_NEEDS_REAL_FIREBASE_PROJECT)،
    // FirebaseMessaging.instance بيرمي استثناء — بنمسكه هنا عشان مسار الدخول
    // العادي (اللي بينادي init ده) مايتأثرش، الإشعارات بس بتفضل معطّلة.
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await supabaseService.registerPushToken(entryCode: entryCode, token: token);
      }

      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        _supabaseService?.registerPushToken(entryCode: entryCode, token: newToken);
      });

      _foregroundSub = FirebaseMessaging.onMessage.listen(_showForegroundBanner);
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_openThread);

      // التطبيق ممكن يكون اتفتح أصلًا من ضغطة على إشعار والتطبيق كان مقفول
      // تمامًا (مش بس في الخلفية) — onMessageOpenedApp مبيتسجلش للحالة دي.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_openThread(initialMessage));
      }
    } catch (_) {
      // Firebase not configured yet — push notifications unavailable.
    }
  }

  void _showForegroundBanner(RemoteMessage message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final title = message.notification?.title ?? 'New patient message';
    final body = message.notification?.body ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isNotEmpty ? '$title: $body' : title),
        action: SnackBarAction(label: 'View', onPressed: () => _openThread(message)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// الـ payload المضمون فيه بس encounter_id (زي ما هو محدد في العقد) —
  /// escalation_id لازم لأي رد/إقفال جوه الشاشة، فبنجيبه من app_portal_inbox
  /// بمطابقة encounter_id بدل ما نفترض شكل تاني للـ payload.
  Future<void> _openThread(RemoteMessage message) async {
    final encounterId = message.data['encounter_id']?.toString();
    final supabaseService = _supabaseService;
    final entryCode = _entryCode;
    if (encounterId == null || encounterId.isEmpty || supabaseService == null || entryCode == null) {
      return;
    }

    PortalEscalation? match;
    try {
      for (final status in ['open', 'replied', 'resolved']) {
        final list = await supabaseService.portalInbox(entryCode: entryCode, status: status);
        for (final e in list) {
          if (e.encounterId == encounterId) {
            match = e;
            break;
          }
        }
        if (match != null) break;
      }
    } catch (_) {
      // Best-effort — worst case the doctor opens the Assistant tab manually.
      return;
    }
    if (match == null) return;

    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => PortalThreadScreen(escalation: match!)),
    );
  }

  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
