/// The "Nocturne" design: tokens and the app's ThemeData.
///
/// The rules behind the values: one dark theme, Inter at
/// weights 400/500 only, outlined (never filled) buttons, accents without
/// glow, and elevation drawn as a 1px edge rather than a blur.
library;

import 'package:flutter/material.dart';

abstract final class Noc {
  // Colours.
  static const bg = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const divider = Color(0x29E9E9ED); // text at 16%
  static const accent = Color(0xFF796CBF); // ramp step 600
  static const accent200 = Color(0xFFE7E5FE);
  static const accent300 = Color(0xFFD2CEFD);
  static const accent400 = Color(0xFFB5ABFC);
  static const accent700 = Color(0xFF5D5294);
  static const accent800 = Color(0xFF423A6A);
  static const accent900 = Color(0xFF2B2741);
  static const neutral100 = Color(0xFFF3F5FE);
  static const neutral300 = Color(0xFFCFD3E5);
  static const neutral400 = Color(0xFFB2B6CA);
  static const neutral500 = Color(0xFF9397AB);
  static const neutral600 = Color(0xFF75798C);
  static const neutral700 = Color(0xFF595D6C);
  static const neutral800 = Color(0xFF3F424D);
  static const scrim = Color(0x8C000000); // black at 55%

  /// Heat-map fills for intensity levels 0–4 (0 is drawn as an outline).
  static const heat = [
    Colors.transparent,
    accent900,
    accent800,
    accent700,
    accent,
  ];

  // Radii.
  static const rSm = 4.0;
  static const rMd = 8.0;
  static const rLg = 14.0;

  /// Horizontal page padding.
  static const gutter = 24.0;

  // Type. Inter everywhere; figures that stand as numbers are tabular.
  static const _tab = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.1,
    letterSpacing: -0.8,
    color: text,
  );
  static const displaySmall = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.1,
    letterSpacing: -0.56,
    color: text,
  );
  static const clock = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.w400,
    height: 1,
    letterSpacing: -0.6,
    color: text,
    fontFeatures: _tab,
  );
  static const sectionHead = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: text,
  );
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: text,
  );
  static const body = TextStyle(fontSize: 15, height: 1.35, color: text);
  static const secondary = TextStyle(fontSize: 14, color: text);
  static const meta = TextStyle(
    fontSize: 12,
    color: neutral400,
    fontFeatures: _tab,
  );
  static const small = TextStyle(fontSize: 11, color: neutral500);
  static const kicker = TextStyle(
    fontSize: 10,
    letterSpacing: 1.2,
    color: accent300,
    fontFeatures: _tab,
  );
  static const figures = TextStyle(fontFeatures: _tab);

  /// Dialogs, drawer, sheets: a 1px edge plus a dark drop, never a glow.
  static const raisedShadow = [
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

ThemeData nocturneTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Noc.accent,
    onPrimary: Noc.neutral100,
    secondary: Noc.accent300,
    onSecondary: Noc.bg,
    tertiary: Noc.accent400,
    onTertiary: Noc.bg,
    error: Noc.accent200,
    onError: Noc.bg,
    surface: Noc.bg,
    onSurface: Noc.text,
    onSurfaceVariant: Noc.neutral400,
    surfaceContainerLowest: Noc.bg,
    surfaceContainerLow: Noc.surface,
    surfaceContainer: Noc.surface,
    surfaceContainerHigh: Noc.surface,
    surfaceContainerHighest: Noc.surface,
    primaryContainer: Noc.accent800,
    onPrimaryContainer: Noc.neutral100,
    secondaryContainer: Noc.surface,
    onSecondaryContainer: Noc.text,
    outline: Noc.divider,
    outlineVariant: Noc.divider,
    scrim: Noc.scrim,
  );

  final primaryButton = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? Noc.accent.withValues(alpha: 0.45)
          : Noc.accent,
    ),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.pressed)
          ? Noc.accent.withValues(alpha: 0.22)
          : Noc.accent.withValues(alpha: 0.12),
    ),
    side: WidgetStateProperty.resolveWith(
      (s) => BorderSide(
        color: s.contains(WidgetState.disabled)
            ? Noc.accent.withValues(alpha: 0.45)
            : Noc.accent,
      ),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
      ),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16.6, vertical: 9.2),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
    ),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Noc.bg,
    canvasColor: Noc.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Noc.text.withValues(alpha: 0.07),
    hoverColor: Noc.text.withValues(alpha: 0.07),
    dividerColor: Noc.divider,
    textTheme: const TextTheme(
      displaySmall: Noc.display,
      headlineSmall: Noc.displaySmall,
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      titleMedium: Noc.title,
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: Noc.body,
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12, color: Noc.neutral400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12),
      labelSmall: TextStyle(fontSize: 11),
    ).apply(bodyColor: Noc.text, displayColor: Noc.text, fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Noc.bg,
      foregroundColor: Noc.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Noc.text,
      ),
    ),
    iconTheme: const IconThemeData(color: Noc.text, size: 22),
    dividerTheme: const DividerThemeData(
      color: Noc.divider,
      thickness: 1,
      space: 1,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: primaryButton),
    // The design has no filled buttons: a FilledButton renders as primary.
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(Noc.accent300),
        overlayColor: WidgetStatePropertyAll(Noc.accent.withValues(alpha: 0.1)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(Noc.text),
        overlayColor: WidgetStatePropertyAll(Noc.text.withValues(alpha: 0.07)),
        fixedSize: const WidgetStatePropertyAll(Size(36, 36)),
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
          ),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Noc.accent300 : Noc.text,
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide(color: Noc.divider)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Noc.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: Noc.neutral500),
      labelStyle: const TextStyle(color: Noc.neutral400, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Noc.accent300),
      helperStyle: const TextStyle(color: Noc.neutral500, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Noc.rMd),
        borderSide: const BorderSide(color: Noc.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Noc.rMd),
        borderSide: const BorderSide(color: Noc.accent),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Noc.rMd),
        borderSide: const BorderSide(color: Noc.divider),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Noc.accent,
      selectionColor: Color(0x55796CBF),
      selectionHandleColor: Noc.accent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Noc.accent,
      linearTrackColor: Noc.neutral800,
      circularTrackColor: Noc.divider,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Noc.bg,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Noc.scrim,
      showDragHandle: true,
      dragHandleColor: Noc.neutral700,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Noc.rLg)),
        side: BorderSide(color: Noc.divider),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Noc.surface,
      surfaceTintColor: Colors.transparent,
      barrierColor: Noc.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Noc.rLg)),
        side: BorderSide(color: Noc.neutral500),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Noc.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: Color(0xD9E9E9ED),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Noc.surface,
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: Noc.text,
      ),
      actionTextColor: Noc.accent300,
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
        side: BorderSide(color: Noc.neutral700),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Noc.bg,
      surfaceTintColor: Colors.transparent,
      scrimColor: Noc.scrim,
      width: 296,
      shape: Border(right: BorderSide(color: Noc.divider)),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Noc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Noc.rMd)),
        side: BorderSide(color: Noc.neutral700),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Noc.neutral400,
      textColor: Noc.text,
    ),
    timePickerTheme: const TimePickerThemeData(backgroundColor: Noc.surface),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Noc.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
