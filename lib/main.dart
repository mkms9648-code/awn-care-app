import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/app_shell.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/push_service.dart';
import 'services/supabase_service.dart';
import 'services/translation_service.dart';
import 'theme/app_theme.dart';

// مفيش router/named routes في التطبيق أصلًا — كل تنقل بيتم بـ
// Navigator.push(MaterialPageRoute(...)) على BuildContext شاشة معيّنة. لكن
// إشعارات البورتال (PushService) ممكن توصل والتطبيق مقفول تمامًا (مفيش أي
// شاشة mounted وقتها)، فمحتاجين مفتاح Navigator عام نقدر ندّيله للـ
// MaterialApp ونستخدمه من بره أي BuildContext. ده أول مفتاح Navigator عام في
// الكودبيز — إضافة جديدة، مش نمط موجود.
final navigatorKey = GlobalKey<NavigatorState>();

/// معالج رسائل الخلفية — لازم يكون top-level function (أو static) ومعلّم
/// بـ @pragma('vm:entry-point') عشان Flutter يقدر يلاقيه من isolate منفصل لما
/// التطبيق يكون في الخلفية أو مقفول. الـ isolate ده جديد كل مرة، فمحتاج
/// Firebase.initializeApp() تاني لوحده.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (!AppConfig.useMockData) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  // Firebase is optional at this point in the repo: there's no real Firebase
  // project wired up yet (android/app/google-services.json is a placeholder —
  // see that file's sibling .PLACEHOLDER_NEEDS_REAL_FIREBASE_PROJECT note),
  // so initializeApp() throws without one. Caught here so a missing config
  // only disables push notifications instead of crashing the app on launch.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // No Firebase project configured yet — push notifications unavailable.
  }

  runApp(const AwnCareApp());
}

class AwnCareApp extends StatelessWidget {
  const AwnCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(
          create: (_) => SupabaseService(
            client: AppConfig.useMockData ? null : Supabase.instance.client,
          ),
        ),
        Provider(
          create: (ctx) => ChatService(
            client: AppConfig.useMockData ? null : Supabase.instance.client,
          ),
        ),
        Provider(create: (_) => TranslationService()),
        Provider(create: (_) => PushService(navigatorKey: navigatorKey)),
        // على مستوى الـ MaterialApp كله (فوق الـ Navigator) عشان يفضل متاح
        // لأي شاشة اتحطّت بـ Navigator.push (زي PatientDetailScreen) — مش
        // بس للشاشات جوه الـ IndexedStack الرئيسي.
        ChangeNotifierProvider(
          create: (ctx) => AuthProvider(
            authService: ctx.read<AuthService>(),
            supabaseService: ctx.read<SupabaseService>(),
            // بيتنادى بعد أي دخول ناجح (كود جديد أو استرجاع جلسة محفوظة) —
            // بيسجّل FCM token للجهاز ده فورًا عشان تنبيهات تصعيد البورتال توصل.
            onAuthenticated: (entryCode) => ctx.read<PushService>().init(
              supabaseService: ctx.read<SupabaseService>(),
              entryCode: entryCode,
            ),
          )..tryRestoreSession(),
        ),
      ],
      // الوضع الليلي إجباري للتطبيق كله — مفيش اختيار للدكتور، وده مقصود
      // (مش تابع لوضع الموبايل نفسه).
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
