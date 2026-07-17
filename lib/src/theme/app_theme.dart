import 'package:flutter/material.dart';

@immutable
class ComiVerseColors extends ThemeExtension<ComiVerseColors> {
  const ComiVerseColors({
    required this.readerBackground,
    required this.surfaceRaised,
    required this.surfaceSubtle,
    required this.border,
    required this.borderSubtle,
    required this.brandPink,
    required this.brandOrange,
    required this.rating,
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color readerBackground;
  final Color surfaceRaised;
  final Color surfaceSubtle;
  final Color border;
  final Color borderSubtle;
  final Color brandPink;
  final Color brandOrange;
  final Color rating;
  final Color success;
  final Color warning;
  final Color info;

  static const dark = ComiVerseColors(
    readerBackground: Color(0xFF07040D),
    surfaceRaised: Color(0xFF151120),
    surfaceSubtle: Color(0x0DFFFFFF),
    border: Color(0x14FFFFFF),
    borderSubtle: Color(0x0AFFFFFF),
    brandPink: Color(0xFFEC4899),
    brandOrange: Color(0xFFFF6B35),
    rating: Color(0xFFFBBF24),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF06B6D4),
  );

  static const light = ComiVerseColors(
    readerBackground: Color(0xFFF8F5F0),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF5F1EC),
    border: Color(0x2963574E),
    borderSubtle: Color(0x1A63574E),
    brandPink: Color(0xFFEC4899),
    brandOrange: Color(0xFFFF6B35),
    rating: Color(0xFFF59E0B),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    info: Color(0xFF0891B2),
  );

  @override
  ComiVerseColors copyWith({
    Color? readerBackground,
    Color? surfaceRaised,
    Color? surfaceSubtle,
    Color? border,
    Color? borderSubtle,
    Color? brandPink,
    Color? brandOrange,
    Color? rating,
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return ComiVerseColors(
      readerBackground: readerBackground ?? this.readerBackground,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      brandPink: brandPink ?? this.brandPink,
      brandOrange: brandOrange ?? this.brandOrange,
      rating: rating ?? this.rating,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  ComiVerseColors lerp(ComiVerseColors? other, double t) {
    if (other == null) return this;
    return ComiVerseColors(
      readerBackground: Color.lerp(readerBackground, other.readerBackground, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      brandPink: Color.lerp(brandPink, other.brandPink, t)!,
      brandOrange: Color.lerp(brandOrange, other.brandOrange, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension ComiVerseTheme on BuildContext {
  ComiVerseColors get cvColors =>
      Theme.of(this).extension<ComiVerseColors>()!;
}

abstract final class AppTheme {
  static const brandPurple = Color(0xFFA855F7);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? ComiVerseColors.dark : ComiVerseColors.light;
    final background =
        isDark ? const Color(0xFF07040D) : const Color(0xFFFAF6F0);
    final surface = isDark ? const Color(0xFF0D0919) : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: brightness,
      surface: surface,
      error: const Color(0xFFEF4444),
    );
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [tokens],
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 11,
          height: 15 / 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.4),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: tokens.border),
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: scheme.primaryContainer.withValues(alpha: 0.45),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: tokens.border),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
