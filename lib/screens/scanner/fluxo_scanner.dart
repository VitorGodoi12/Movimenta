import 'package:flutter/material.dart';
import 'package:movimenta/screens/estoque/produto_detalhe_screen.dart';
import 'package:movimenta/screens/estoque/produto_form_screen.dart';
import 'package:movimenta/screens/scanner/scanner_screen.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/widgets/dialogos.dart';

/// Escaneia um código: abre o produto se existir,
/// ou oferece cadastrar um novo com esse código.
Future<void> escanearEAbrir(BuildContext context) async {
  final codigo = await lerCodigo(context);
  if (codigo == null || !context.mounted) return;

  final produto = estoque.porCodigo(codigo);
  if (produto != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoDetalheScreen(produto: produto),
      ),
    );
    return;
  }

  final cadastrar = await confirmar(
    context,
    titulo: 'Produto não encontrado',
    texto: 'O código $codigo ainda não está cadastrado. Quer cadastrar agora?',
    rotuloConfirmar: 'Cadastrar',
  );
  if (cadastrar && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoFormScreen(codigoInicial: codigo),
      ),
    );
  }
}
