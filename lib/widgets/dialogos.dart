import 'package:flutter/material.dart';
import 'package:movimenta/theme/app_theme.dart';

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String rotuloConfirmar,
  bool destrutivo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destrutivo
              ? TextButton.styleFrom(foregroundColor: AppCores.zerado)
              : null,
          child: Text(rotuloConfirmar),
        ),
      ],
    ),
  );
  return resposta ?? false;
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
