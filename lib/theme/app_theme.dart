import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Paleta do Stokio: roxo claro, branco e preto.
/// Amarelo e vermelho aparecem só para sinalizar estoque baixo/zerado.
class AppCores {
  AppCores._();

  static const roxo = Color(0xFFB69CF2);
  static const roxoSuave = Color(0xFFEEE8FC);
  static const roxoCampo = Color(0xFFF6F3FD);
  static const branco = Color(0xFFFFFFFF);
  static const preto = Color(0xFF000000);
  static const cinza = Color(0xFF65626F);
  static const linha = Color(0xFFE6E1F3);

  static const baixo = Color(0xFFF2B53D);
  static const baixoFundo = Color(0xFFFFF0CC);
  static const zerado = Color(0xFFE5484D);
  static const zeradoFundo = Color(0xFFFFE1E2);
}

class AppTheme {
  AppTheme._();

  static ThemeData claro() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    final esquema = ColorScheme.fromSeed(
      seedColor: AppCores.roxo,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppCores.roxo,
      onPrimary: AppCores.preto,
      secondary: AppCores.roxo,
      onSecondary: AppCores.preto,
      primaryContainer: AppCores.roxoSuave,
      onPrimaryContainer: AppCores.preto,
      surface: AppCores.branco,
      onSurface: AppCores.preto,
      outline: AppCores.linha,
      error: AppCores.zerado,
    );

    final texto = base.textTheme.apply(
      bodyColor: AppCores.preto,
      displayColor: AppCores.preto,
    );

    final raio14 = BorderRadius.circular(14);

    return base.copyWith(
      colorScheme: esquema,
      scaffoldBackgroundColor: AppCores.branco,
      textTheme: texto,
      dividerColor: AppCores.linha,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppCores.branco,
        foregroundColor: AppCores.preto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppCores.preto,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppCores.roxo,
          foregroundColor: AppCores.preto,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppCores.preto,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppCores.preto, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppCores.preto,
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppCores.roxoCampo,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: AppCores.cinza),
        floatingLabelStyle: const TextStyle(
          color: AppCores.preto,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: AppCores.cinza),
        border: OutlineInputBorder(
          borderRadius: raio14,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: raio14,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: raio14,
          borderSide: const BorderSide(color: AppCores.preto, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: raio14,
          borderSide: const BorderSide(color: AppCores.zerado, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: raio14,
          borderSide: const BorderSide(color: AppCores.zerado, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppCores.branco,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppCores.roxo,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          texto.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: AppCores.preto),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppCores.branco,
        selectedColor: AppCores.roxo,
        side: const BorderSide(color: AppCores.linha),
        shape: const StadiumBorder(),
        labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppCores.branco,
          foregroundColor: AppCores.preto,
          selectedBackgroundColor: AppCores.roxo,
          selectedForegroundColor: AppCores.preto,
          side: const BorderSide(color: AppCores.linha),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppCores.roxo,
        foregroundColor: AppCores.preto,
        elevation: 2,
        extendedTextStyle:
            texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppCores.preto,
        contentTextStyle: texto.bodyMedium?.copyWith(color: AppCores.branco),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: raio14),
      ),
    );
  }
}
