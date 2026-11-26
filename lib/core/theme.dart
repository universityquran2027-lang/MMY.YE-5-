import 'package:flutter/material.dart';
import 'brand.dart';

/// Design system موحّد للتطبيق على Android وWindows.
///
/// الألوان من الشعار الرسمي حرفياً. الخط Tajawal مضمّن محلياً (يعمل دون إنترنت).
/// أنصاف الأقطار: 12 للحقول والأزرار، 16 للبطاقات، 28 للنوافذ والأوراق السفلية.
class AppTheme {
  static const fontFamily = 'Tajawal';

  static ThemeData light() => _build(
        ColorScheme.light(
          primary: Brand.green,
          onPrimary: Brand.white,
          primaryContainer: Brand.greenTint,
          onPrimaryContainer: Brand.greenDark,
          secondary: Brand.red,
          onSecondary: Brand.white,
          secondaryContainer: const Color(0xFFFDE7E7),
          onSecondaryContainer: const Color(0xFF8A1517),
          surface: Brand.white,
          onSurface: Brand.gray900,
          error: Brand.error,
          outline: Brand.gray200,
          outlineVariant: const Color(0xFFEBEEEC),
          surfaceContainerLowest: Brand.white,
          surfaceContainerLow: const Color(0xFFF9FBF9),
          surfaceContainer: const Color(0xFFF3F6F4),
          surfaceContainerHigh: const Color(0xFFEDF1EE),
          surfaceContainerHighest: Brand.gray50,
        ),
        scaffold: const Color(0xFFF4F7F5),
      );

  static ThemeData dark() => _build(
        ColorScheme.dark(
          primary: Brand.greenLight,
          onPrimary: Brand.white,
          primaryContainer: const Color(0xFF173B26),
          onPrimaryContainer: const Color(0xFFBFE6CC),
          secondary: const Color(0xFFFF6B6E),
          onSecondary: const Color(0xFF3A0506),
          secondaryContainer: const Color(0xFF5A1416),
          onSecondaryContainer: const Color(0xFFFFD9D9),
          surface: const Color(0xFF151A17),
          onSurface: const Color(0xFFE8ECEA),
          error: const Color(0xFFF2B8B5),
          outline: const Color(0xFF38403B),
          outlineVariant: const Color(0xFF2A312D),
          surfaceContainerLowest: const Color(0xFF0F1411),
          surfaceContainerLow: const Color(0xFF181E1A),
          surfaceContainer: const Color(0xFF1C231F),
          surfaceContainerHigh: const Color(0xFF222A25),
          surfaceContainerHighest: const Color(0xFF28312B),
        ),
        scaffold: const Color(0xFF101512),
      );

  static ThemeData _build(ColorScheme cs, {required Color scaffold}) {
    final fieldRadius = BorderRadius.circular(12);
    final cardRadius = BorderRadius.circular(16);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffold,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.6),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.6),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: cs.outline.withValues(alpha: .6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: .7)),
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: .45)),
        prefixIconColor: cs.onSurface.withValues(alpha: .6),
        suffixIconColor: cs.onSurface.withValues(alpha: .6),
        border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: cs.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: cs.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: cs.error, width: 2)),
        disabledBorder: OutlineInputBorder(
            borderRadius: fieldRadius, borderSide: BorderSide(color: cs.outline.withValues(alpha: .5))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainer,
        selectedColor: cs.primaryContainer,
        side: BorderSide(color: cs.outline.withValues(alpha: .6)),
        labelStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: cs.onSurface.withValues(alpha: .75),
      ),
      dividerTheme: DividerThemeData(color: cs.outline.withValues(alpha: .6), thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: .25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.brightness == Brightness.dark ? const Color(0xFFE8ECEA) : Brand.gray900,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: cs.brightness == Brightness.dark ? Brand.gray900 : Brand.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: Brand.gray900, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: fontFamily, color: Brand.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        circularTrackColor: cs.outline.withValues(alpha: .35),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(cs.onSurface.withValues(alpha: .25)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(color: cs.onSurface.withValues(alpha: .7)),
        selectedLabelTextStyle: TextStyle(fontFamily: fontFamily, color: cs.primary, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle:
            TextStyle(fontFamily: fontFamily, color: cs.onSurface.withValues(alpha: .72), fontWeight: FontWeight.w500),
        groupAlignment: -.85,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? cs.primary : cs.onSurface.withValues(alpha: .7),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 11.5,
              color: states.contains(WidgetState.selected) ? cs.primary : cs.onSurface.withValues(alpha: .7),
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            )),
      ),
    );
  }
}
