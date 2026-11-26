import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';

Future<void> escanearEAbrir(
  BuildContext context, {
  bool lojaInicial = false,
}) async {
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
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ProdutoFormScreen(
        codigoInicial: codigo,
        lojaInicial: lojaInicial,
        vincularProduto: semCodigo.isEmpty
            ? null
            : (context) => _escolherProduto(context, semCodigo),
      ),
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
