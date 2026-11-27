import 'package:flutter/material.dart';
import 'package:stokio/services/catalogo_local.dart';
import 'package:stokio/services/sugestao_catalogo.dart';

class CatalogoProdutosScreen extends StatefulWidget {
  const CatalogoProdutosScreen({super.key, this.buscaInicial = ''});

  final String buscaInicial;

  @override
  State<CatalogoProdutosScreen> createState() => _CatalogoProdutosScreenState();
}

class _CatalogoProdutosScreenState extends State<CatalogoProdutosScreen> {
  late final _dados = CatalogoLocal.listar();
  late final _busca = TextEditingController(text: widget.buscaInicial);
  String? _categoria;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<String> _termos(String valor) => valor
      .toUpperCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((termo) => termo.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catálogo de produtos')),
    body: FutureBuilder<Map<String, ProdutoCatalogo>>(
      future: _dados,
      builder: (context, estado) {
        if (estado.hasError) {
          return const Center(
            child: Text(
              'Catálogo indisponível. Volte para cadastrar manualmente.',
            ),
          );
        }
        final dados = estado.data;
        if (dados == null)
          return const Center(child: CircularProgressIndicator());
        final termos = _termos(_busca.text);
        final grupos =
            dados.values.map((produto) => produto.categoria).toSet().toList()
              ..sort();
        final resultados = dados.entries.where((item) {
          final texto = item.value.nome.toUpperCase() + ' ' + item.key;
          return (_categoria == null || item.value.categoria == _categoria) &&
              termos.every(texto.contains);
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _busca,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Nome, marca ou código',
                      helperText: 'Catálogo salvo no aparelho',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categoria ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todas')),
                      for (final grupo in grupos)
                        DropdownMenuItem(value: grupo, child: Text(grupo)),
                    ],
                    onChanged: (valor) =>
                        setState(() => _categoria = valor == '' ? null : valor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: resultados.isEmpty
                  ? Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cadastrar manualmente'),
                      ),
                    )
                  : ListView.separated(
                      itemCount: resultados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = resultados[i];
                        final SugestaoCatalogo sugestao = (
                          codigo: item.key,
                          nome: item.value.nome,
                          categoria: item.value.categoria,
                        );
                        return ListTile(
                          title: Text(item.value.nome),
                          subtitle: Text(
                            item.value.categoria + ' · ' + item.key,
                          ),
                          trailing: IconButton(
                            tooltip: 'Usar este produto',
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => Navigator.pop(context, sugestao),
                          ),
                          onTap: () => Navigator.pop(context, sugestao),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}
