import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Paleta do Movimenta.
/// Amarelo e vermelho aparecem só para sinalizar estoque baixo/zerado.
class AppCores {
  AppCores._();

  static const roxoForte = Color(0xFF6242A7);
  static const roxo = Color(0xFFB69CF2);
  static const roxoSuave = Color(0xFFEEE8FC);
  static const roxoCampo = Color(0xFFFFFFFF);
  static const fundo = Color(0xFFF7F5FB);
  static const roxoAcao = Color(0xFF6242A7);
  static const branco = Color(0xFFFFFFFF);
  static const preto = Color(0xFF181125);
  static const cinza = Color(0xFF65626F);
  static const linha = Color(0xFFE6E1F3);

  static const baixo = Color(0xFFF2B53D);
  static const baixoFundo = Color(0xFFFFF0CC);
  static const zerado = Color(0xFFE5484D);
  static const zeradoFundo = Color(0xFFFFE1E2);
}

class AppTheme {
  AppTheme._();

  static ThemeData claro() => _criar(Brightness.light);
  static ThemeData escuro() => _criar(Brightness.dark);

  static ThemeData _criar(Brightness brilho) {
    final escuro = brilho == Brightness.dark;
    final base = ThemeData(useMaterial3: true, brightness: brilho);
    final fundo = escuro ? const Color(0xFF171320) : AppCores.fundo;
    final superficie = escuro ? const Color(0xFF241D31) : AppCores.branco;
    final campo = escuro ? const Color(0xFF302640) : AppCores.roxoCampo;
    final textoPrincipal = escuro ? const Color(0xFFF5EFFC) : AppCores.preto;
    final auxiliar = escuro ? const Color(0xFFD1C3E3) : AppCores.cinza;
    final borda = escuro ? const Color(0xFF554669) : AppCores.linha;
    final acao = escuro ? const Color(0xFFD4B9FF) : AppCores.roxoAcao;
    final sobreAcao = escuro ? AppCores.preto : AppCores.branco;
    final destaque = escuro ? const Color(0xFF3C2B53) : AppCores.roxoSuave;

    final esquema =
        ColorScheme.fromSeed(
          seedColor: AppCores.roxoForte,
          brightness: brilho,
        ).copyWith(
          primary: acao,
          onPrimary: sobreAcao,
          primaryContainer: destaque,
          onPrimaryContainer: textoPrincipal,
          surface: superficie,
          surfaceContainerHighest: campo,
          onSurface: textoPrincipal,
          onSurfaceVariant: auxiliar,
          outlineVariant: borda,
        );
    final texto = base.textTheme.apply(
      bodyColor: textoPrincipal,
      displayColor: textoPrincipal,
    );
    final raio14 = BorderRadius.circular(14);

    return base.copyWith(
      colorScheme: esquema,
      scaffoldBackgroundColor: fundo,
      textTheme: texto,
      dividerColor: borda,
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borda),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: fundo,
        foregroundColor: acao,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textoPrincipal,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: acao,
          foregroundColor: sobreAcao,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: acao,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: borda),
          shape: RoundedRectangleBorder(borderRadius: raio14),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: acao,
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: campo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: auxiliar),
        floatingLabelStyle: TextStyle(
          color: textoPrincipal,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: auxiliar),
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
          borderSide: BorderSide(color: textoPrincipal, width: 1.5),
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
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: destaque,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          texto.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: textoPrincipal)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: superficie,
        selectedColor: destaque,
        side: BorderSide(color: borda),
        shape: const StadiumBorder(),
        labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: superficie,
          foregroundColor: acao,
          selectedBackgroundColor: destaque,
          selectedForegroundColor: textoPrincipal,
          side: BorderSide(color: borda),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: destaque,
        foregroundColor: acao,
        elevation: 2,
        extendedTextStyle: texto.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textoPrincipal,
        contentTextStyle: texto.bodyMedium?.copyWith(color: fundo),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: raio14),
      ),
    );
  }
}

extension CoresDoMovimenta on BuildContext {
  ColorScheme get cores => Theme.of(this).colorScheme;
}
