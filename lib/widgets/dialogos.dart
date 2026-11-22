import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';

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

/// Aviso com botão "Desfazer" que reverte as movimentações informadas.
void avisarComDesfazer(
  BuildContext context,
  String texto,
  List<Movimentacao> movs,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: AppCores.roxo,
          onPressed: () => estoque.desfazerVarias(movs),
        ),
      ),
    );
}
