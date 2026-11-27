import 'package:stokio/services/mercado_firebase.dart';
import 'package:stokio/screens/login/acesso_mercado_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stokio/screens/login/boas_vindas_screen.dart';
import 'package:stokio/screens/shell_screen.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/theme/tema_preferencia.dart';

class StokioApp extends StatelessWidget {
  const StokioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: TemaPreferencia.modo,
      builder: (context, modo, _) => MaterialApp(
        title: 'Movimenta',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro(),
        darkTheme: AppTheme.escuro(),
        themeMode: modo,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _EntradaMovimenta(
          child: MercadoFirebase.habilitado
              ? const AcessoMercadoScreen()
              : perfil.cliente == null
              ? const BoasVindasScreen()
              : const ShellScreen(),
        ),
      ),
    );
  }
}

class _EntradaMovimenta extends StatelessWidget {
  const _EntradaMovimenta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progresso, tela) => Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: AlwaysStoppedAnimation(progresso),
            child: tela,
          ),
          if (progresso < 1)
            IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 1 - progresso,
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Transform.scale(
                        scale: .92 + .08 * progresso,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/stokio.png',
                            width: 88,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
