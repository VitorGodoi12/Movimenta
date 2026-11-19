import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';

Future<void> escanearEAbrir(BuildContext context) async {
  final codigo = await lerCodigo(context);
  if (codigo == null || !context.mounted) return;

  final produto = estoque.porCodigo(codigo);
  if (produto != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoDetalheScreen(produto: produto)),
    );
    return;
  }

  final semCodigo =
      estoque.produtos.where((p) => p.codigoBarras?.isNotEmpty != true).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  final novo = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Código ainda sem produto'),
      content: Text('Código $codigo'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Cancelar'),
        ),
        if (semCodigo.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Vincular a produto'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogo, true),
          child: const Text('Cadastrar novo'),
        ),
      ],
    ),
  );
  if (novo == null || !context.mounted) return;
  final existente = novo ? null : await _escolherProduto(context, semCodigo);
  if (!context.mounted || (!novo && existente == null)) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ProdutoFormScreen(produto: existente, codigoInicial: codigo),
    ),
  );
}

Future<Produto?> _escolherProduto(
  BuildContext context,
  List<Produto> produtos,
) {
  var busca = '';
  return showDialog<Produto>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (context, atualizar) {
        final filtrados = produtos
            .where(
              (p) => '${p.nome} ${p.categoria}'.toLowerCase().contains(busca),
            )
            .toList();
        return AlertDialog(
          title: const Text('Escolher produto sem código'),
          content: SizedBox(
            width: 420,
            height: 320,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar produto',
                  ),
                  onChanged: (texto) =>
                      atualizar(() => busca = texto.trim().toLowerCase()),
                ),
                Expanded(
                  child: filtrados.isEmpty
                      ? const Center(child: Text('Nenhum produto encontrado'))
                      : ListView.builder(
                          itemCount: filtrados.length,
                          itemBuilder: (context, i) {
                            final produto = filtrados[i];
                            return ListTile(
                              title: Text(produto.nome),
                              subtitle: Text(
                                '${produto.categoria} · ${produto.unidade}',
                              ),
                              onTap: () => Navigator.pop(dialogo, produto),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    ),
  );
}
