import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/app_shell.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

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
        // على مستوى الـ MaterialApp كله (فوق الـ Navigator) عشان يفضل متاح
        // لأي شاشة اتحطّت بـ Navigator.push (زي PatientDetailScreen) — مش
        // بس للشاشات جوه الـ IndexedStack الرئيسي.
        ChangeNotifierProvider(
          create: (ctx) => AuthProvider(
            authService: ctx.read<AuthService>(),
            supabaseService: ctx.read<SupabaseService>(),
          )..tryRestoreSession(),
        ),
      ],
      // الوضع الليلي إجباري للتطبيق كله — مفيش اختيار للدكتور، وده مقصود
      // (مش تابع لوضع الموبايل نفسه).
      child: MaterialApp(
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
