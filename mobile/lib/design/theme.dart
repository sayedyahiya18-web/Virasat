import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Assembles the Material theme from the tokens. Anything Material draws for
/// us — buttons, sheets, fields — is configured once here so it matches the
/// hand-built widgets.
ThemeData buildVirasatTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: VColor.terracotta,
      onPrimary: Colors.white,
      secondary: VColor.gold,
      onSecondary: Colors.white,
      surface: VColor.surface,
      onSurface: VColor.ink,
      surfaceContainerHighest: VColor.surfaceMuted,
      outline: VColor.hairline,
      error: Color(0xFFB3261E),
    ),
    scaffoldBackgroundColor: VColor.canvas,
    fontFamily: VFont.sans,
  );

  return base.copyWith(
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: VColor.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: VFont.serif(size: 20, weight: 600),
      iconTheme: const IconThemeData(color: VColor.ink, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VColor.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: VColor.terracottaWash,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 23,
          color: s.contains(WidgetState.selected)
              ? VColor.terracotta
              : VColor.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => VFont.sansStyle(
          size: 11,
          weight: s.contains(WidgetState.selected) ? 700 : 500,
          color: s.contains(WidgetState.selected)
              ? VColor.terracotta
              : VColor.inkMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VColor.terracotta,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.xl),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: VFont.sansStyle(size: 15, weight: 700, color: Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VColor.ink,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: VColor.hairline, width: 1.4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: VFont.sansStyle(size: 15, weight: 600, color: VColor.ink),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: VColor.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: VColor.hairline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: VColor.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VRadius.lg)),
      titleTextStyle: VFont.serif(size: 20, weight: 600),
      contentTextStyle: VFont.body,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VColor.surfaceMuted,
      hintStyle: VFont.sansStyle(size: 15, color: VColor.inkMuted),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: VSpace.lg, vertical: VSpace.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: VColor.terracotta, width: 1.6),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: VFont.displayLarge,
      displayMedium: VFont.displayMedium,
      titleLarge: VFont.title,
      titleMedium: VFont.cardTitle,
      bodyLarge: VFont.body,
      bodyMedium: VFont.bodySmall,
      labelLarge: VFont.label,
      labelSmall: VFont.caption,
    ),
  );
}

/// Dark icons on the light canvas, edge-to-edge.
const virasatOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: VColor.surface,
  systemNavigationBarIconBrightness: Brightness.dark,
);
