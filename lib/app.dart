import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:movimenta/screens/login/boas_vindas_screen.dart';
import 'package:movimenta/screens/shell_screen.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/theme/app_theme.dart';

class MovimentaApp extends StatelessWidget {
  const MovimentaApp({super.key});

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
