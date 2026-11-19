import 'package:flutter/material.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/importacao_estoque.dart';

class ImportarEstoqueScreen extends StatefulWidget {
  const ImportarEstoqueScreen({super.key});

  @override
  State<ImportarEstoqueScreen> createState() => _ImportarEstoqueScreenState();
}

class _ImportarEstoqueScreenState extends State<ImportarEstoqueScreen> {
  final _texto = TextEditingController();
  ListaImportada? _previa;
  bool _salvando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _importar(ListaImportada previa) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await estoque.importarContagem(previa.itens);
      if (mounted) Navigator.pop(context, previa.itens.length);
    } on StateError catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.message.toString())));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = _previa;
    final grupos = <String, List<ItemImportado>>{};
    for (final item in previa?.itens ?? const <ItemImportado>[]) {
      (grupos[item.categoria] ??= []).add(item);
    }
    final categorias = grupos.keys.toList()..sort();

    return PopScope(
      canPop: !_salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Importar lista de estoque')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (previa == null) ...[
              TextField(
                controller: _texto,
                keyboardType: TextInputType.multiline,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Cole a lista de estoque',
                  hintText: '10 x Itaipava 350\n5 cx salsicha\n2 fardos papel higiênico',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(
                    () => _previa = interpretarListaEstoque(_texto.text),
                  );
                },
                child: const Text('Conferir lista'),
              ),
            ] else ...[
              Text(
                '${previa.itens.length} produtos em ${categorias.length} categorias',
              ),
              const Text(
                'As quantidades da lista substituem a contagem dos produtos correspondentes.',
              ),
              TextButton(
                onPressed: _salvando
                    ? null
                    : () => setState(() => _previa = null),
                child: const Text('Editar texto da lista'),
              ),
              if (previa.repetidos.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    '${previa.repetidos.length} repetições · vale a última contagem',
                  ),
                  children: [
                    for (final linha in previa.repetidos)
                      ListTile(title: Text(linha)),
                  ],
                ),
              if (previa.pendencias.isNotEmpty)
                ExpansionTile(
                  initiallyExpanded: true,
                  title: Text('${previa.pendencias.length} linhas a revisar'),
                  subtitle: const Text(
                    'Essas linhas ficam fora da importação.',
                  ),
                  children: [
                    for (final linha in previa.pendencias)
                      ListTile(title: Text(linha)),
                  ],
                ),
              for (final categoria in categorias)
                ExpansionTile(
                  title: Text(categoria),
                  children: [
                    for (final item in grupos[categoria]!)
                      ListTile(
                        title: Text(item.nome),
                        trailing: Text('${item.quantidade} ${item.unidade}'),
                      ),
                  ],
                ),
            ],
          ],
        ),
        bottomNavigationBar: previa == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: _salvando || previa.itens.isEmpty
                      ? null
                      : () => _importar(previa),
                  child: Text(
                    _salvando
                        ? 'Importando…'
                        : 'Importar ${previa.itens.length} produtos',
                  ),
                ),
              ),
      ),
    );
  }
}
