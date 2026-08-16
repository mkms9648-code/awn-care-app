import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional medical theme — Awn brand identity: deep navy chrome,
/// vivid blue accent, fully-rounded pill controls, Plus Jakarta Sans type.
class AppTheme {
  AppTheme._();

  // Brand accent (from the Awn marketing site).
  static const Color primaryBlue = Color(0xFF3B6FF2);
  static const Color primaryBlueLight = Color(0xFF5B8DFF);
  static const Color accentOrange = Color(0xFFE65100);
  static const Color criticalRed = Color(0xFFC62828);
  static const Color successGreen = Color(0xFF2E7D32);

  // Deep navy chrome used for the app bar / bottom nav in both themes,
  // mirroring the always-dark header on the marketing site.
  static const Color navyChrome = Color(0xFF0A0E1A);
  static const Color mutedOnNavy = Color(0xFF8B94AC);

  // Light theme surfaces.
  static const Color surfaceLight = Color(0xFFF4F7FC);
  static const Color cardLight = Colors.white;

  // Dark theme surfaces.
  static const Color surfaceDark = Color(0xFF0A0E1A);
  static const Color cardDark = Color(0xFF141B2E);

  static TextTheme _textTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base);
  }

  /// المتحكم القطاعي (SegmentedButton) بيوصله يعتمد على ألوان الـ ColorScheme
  /// الافتراضية لو متركش، وده بيدّي تباين ضعيف جدًا للقطاعات الغير مختارة في
  /// الوضع الليلي (نص غامق على خلفية غامقة، شبه مش ظاهر). بنحدد الألوان
  /// صراحة عشان كل القطاعات تبقى واضحة في الوضعين.
  static SegmentedButtonThemeData _segmentedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final selectedBg = isDark ? primaryBlueLight : primaryBlue;
    final unselectedBg = isDark ? cardDark : cardLight;
    final unselectedFg = isDark ? Colors.white : Colors.black87;
    final border = isDark ? Colors.white24 : Colors.black26;

    return SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? selectedBg : unselectedBg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? Colors.white : unselectedFg;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: border)),
      ),
    );
  }

  static final PageTransitionsTheme _motion = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const _FadeSlidePageTransitionsBuilder(),
    },
  );

  static NavigationBarThemeData get _navigationBarTheme => NavigationBarThemeData(
        backgroundColor: navyChrome,
        elevation: 0,
        height: 64,
        indicatorColor: primaryBlue.withValues(alpha: 0.28),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : mutedOnNavy,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryBlueLight : mutedOnNavy,
            size: 24,
          );
        }),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        textTheme: _textTheme(Brightness.light),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentOrange,
          error: criticalRed,
          surface: surfaceLight,
        ),
        scaffoldBackgroundColor: surfaceLight,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: navyChrome,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: _navigationBarTheme,
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardLight,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: const StadiumBorder()),
        ),
        chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          side: BorderSide(color: primaryBlue.withValues(alpha: 0.15)),
          backgroundColor: primaryBlue.withValues(alpha: 0.06),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),
        segmentedButtonTheme: _segmentedButtonTheme(Brightness.light),
        pageTransitionsTheme: _motion,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        textTheme: _textTheme(Brightness.dark),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlueLight,
          brightness: Brightness.dark,
          primary: primaryBlueLight,
          secondary: accentOrange,
          error: criticalRed,
          surface: surfaceDark,
        ),
        scaffoldBackgroundColor: surfaceDark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: navyChrome,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: _navigationBarTheme,
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardDark,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryBlueLight, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlueLight,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: const StadiumBorder()),
        ),
        chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          side: BorderSide(color: primaryBlueLight.withValues(alpha: 0.2)),
          backgroundColor: primaryBlueLight.withValues(alpha: 0.1),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlueLight,
          foregroundColor: Colors.white,
        ),
        segmentedButtonTheme: _segmentedButtonTheme(Brightness.dark),
        pageTransitionsTheme: _motion,
      );
}

/// Subtle fade + upward-slide push transition used across all platforms,
/// echoing the calm, modern motion of the Awn marketing site.
class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
