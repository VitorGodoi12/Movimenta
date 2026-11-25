import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stokio/screens/login/boas_vindas_screen.dart';
import 'package:stokio/screens/shell_screen.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';

class StokioApp extends StatelessWidget {
  const StokioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movimenta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: perfil.cliente == null
          ? const BoasVindasScreen()
          : const ShellScreen(),
    );
  }
}
