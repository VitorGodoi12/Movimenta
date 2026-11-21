import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Paleta do Stokio: verde claro, branco e preto.
/// Amarelo e vermelho aparecem só para sinalizar estoque baixo/zerado.
class AppCores {
  AppCores._();

  static const verdeForte = Color(0xFF0B5C45);
  static const verde = Color(0xFFBCE9D9);
  static const verdeSuave = Color(0xFFDFF3EC);
  static const verdeCampo = Color(0xFFFFFFFF);
  static const fundo = Color(0xFFF4F6F3);
  static const verdeAcao = Color(0xFF0D8662);
  static const branco = Color(0xFFFFFFFF);
  static const preto = Color(0xFF12201B);
  static const cinza = Color(0xFF55665E);
  static const linha = Color(0xFFDFE7DF);

  static const baixo = Color(0xFFF2B53D);
  static const baixoFundo = Color(0xFFFFF0CC);
  static const zerado = Color(0xFFE5484D);
  static const zeradoFundo = Color(0xFFFFE1E2);
}

class AppTheme {
  AppTheme._();

  static ThemeData claro() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    final esquema =
        ColorScheme.fromSeed(
          seedColor: AppCores.verde,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppCores.verde,
          onPrimary: AppCores.preto,
          secondary: AppCores.verde,
          onSecondary: AppCores.preto,
          primaryContainer: AppCores.verdeSuave,
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
      scaffoldBackgroundColor: AppCores.fundo,
      textTheme: texto,
      dividerColor: AppCores.linha,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppCores.fundo,
        foregroundColor: AppCores.verdeForte,
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
          backgroundColor: AppCores.verdeAcao,
          foregroundColor: AppCores.branco,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppCores.verdeForte,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppCores.linha),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppCores.verdeForte,
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppCores.verdeCampo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
        indicatorColor: AppCores.verde,
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
        selectedColor: AppCores.verde,
        side: const BorderSide(color: AppCores.linha),
        shape: const StadiumBorder(),
        labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppCores.branco,
          foregroundColor: AppCores.verdeForte,
          selectedBackgroundColor: AppCores.verde,
          selectedForegroundColor: AppCores.preto,
          side: const BorderSide(color: AppCores.linha),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppCores.verde,
        foregroundColor: AppCores.verdeForte,
        elevation: 2,
        extendedTextStyle: texto.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
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
