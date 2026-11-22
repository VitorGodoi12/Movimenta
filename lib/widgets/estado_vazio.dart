import 'package:flutter/material.dart';
import 'package:stokio/theme/app_theme.dart';

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
  });

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppCores.roxoSuave,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: t.bodyMedium?.copyWith(color: AppCores.cinza),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
