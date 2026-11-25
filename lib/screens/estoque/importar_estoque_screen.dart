import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/importacao_estoque.dart';
import 'package:stokio/widgets/buscar_catalogo.dart';

class ImportarEstoqueScreen extends StatefulWidget {
  const ImportarEstoqueScreen({super.key});

  @override
  State<ImportarEstoqueScreen> createState() => _ImportarEstoqueScreenState();
}

class _ImportarEstoqueScreenState extends State<ImportarEstoqueScreen> {
  final _texto = TextEditingController();
  ListaImportada? _previa;
  bool _salvando = false;
  final _fatores = <String, int>{};
  final _quantidades = <ItemImportado, int?>{};
  final _selecionados = <ItemImportado, ItemImportado>{};

  Future<void> _sugerir(ItemImportado item) async {
    final sugestao = await buscarNoCatalogo(context, item.nome);
    if (sugestao == null || !mounted) return;
    setState(() {
      _selecionados[item] = item.revisar(
        nome: sugestao.nome,
        codigoBarras: sugestao.codigo,
      );
    });
  }

  ItemImportado _revisar(ItemImportado item) {
    final escolhido = _selecionados[item] ?? item;
    return _comFator(
      escolhido.revisar(quantidade: _quantidades[item] ?? item.quantidade),
      item.chave,
    );
  }

  final _campos = <ItemImportado, TextEditingController>{};

  TextEditingController _controlador(ItemImportado item, bool pendente) =>
      _campos.putIfAbsent(
        item,
        () => TextEditingController(
          text: pendente ? '' : item.quantidade.toString(),
        ),
      );

  ItemImportado _comFator(ItemImportado item, String chave) {
    final fator = _fatores[chave];
    return fator == null ? item : item.comFator(fator);
  }

  @override
  void dispose() {
    _texto.dispose();
    for (final campo in _campos.values) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _importar(List<ItemImportado> itens) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await estoque.importarContagem(itens.map(_revisar).toList());
      if (mounted) Navigator.pop(context, itens.length);
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
    final itens = [...?previa?.itens, ...?previa?.semQuantidade];
    final linhaIncompleta =
        previa != null &&
        previa.pendencias.length > previa.semQuantidade.length;
    final faltaQuantidade = itens.any(
      (item) => _quantidades.containsKey(item) && _quantidades[item] == null,
    );
    final grupos = <String, List<ItemImportado>>{};
    for (final item in itens) {
      (grupos[item.categoria] ??= []).add(item);
    }
    final categorias = grupos.keys.toList()..sort();
    final semConversao = itens
        .where(
          (item) => estoque.fatorImportacao(_selecionados[item] ?? item) == 0,
        )
        .toList();
    final faltaConversao = semConversao.any(
      (item) => !_fatores.containsKey(item.chave),
    );

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
                  setState(() {
                    _previa = interpretarListaEstoque(_texto.text);
                    _quantidades.clear();
                    _selecionados.clear();
                    _fatores.clear();
                    for (final item in _previa!.semQuantidade) {
                      _quantidades[item] = null;
                    }
                  });
                },
                child: const Text('Conferir lista'),
              ),
            ] else ...[
              Text(
                '${itens.length} produtos em ${categorias.length} categorias',
              ),
              const Text(
                'A lista atualiza o saldo de Estoque e preserva o saldo de Loja. As embalagens novas são convertidas em unidades.',
              ),
              TextButton(
                onPressed: _salvando
                    ? null
                    : () => setState(() => _previa = null),
                child: const Text('Editar texto da lista'),
              ),
              if (semConversao.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Quantas unidades vêm em cada embalagem?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final item in semConversao)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextFormField(
                      key: ValueKey(item.chave),
                      initialValue: _fatores[item.chave]?.toString(),
                      enabled: !_salvando,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${item.nome} · unidades por ${item.unidade == 'cx' ? 'caixa' : 'fardo'}',
                        helperText:
                            '${item.quantidade} ${item.unidade} na lista',
                      ),
                      onChanged: (texto) => setState(() {
                        final fator = int.tryParse(texto.trim());
                        if (fator == null || fator < 1 || fator > 99999) {
                          _fatores.remove(item.chave);
                        } else {
                          _fatores[item.chave] = fator;
                        }
                      }),
                    ),
                  ),
              ],
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
              if (linhaIncompleta)
                const ListTile(
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Revise as linhas sem nome no texto da lista.'),
                ),
              if (faltaQuantidade)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.edit_note_outlined),
                    title: Text('Há itens sem quantidade'),
                    subtitle: Text(
                      'Preencha todos os campos em branco nos grupos abaixo. Use 0 para itens zerados.',
                    ),
                  ),
                ),
              for (final categoria in categorias)
                ExpansionTile(
                  title: Text(categoria),
                  initiallyExpanded: grupos[categoria]!.any(
                    previa.semQuantidade.contains,
                  ),
                  children: [
                    for (final item in grupos[categoria]!)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text((_selecionados[item] ?? item).nome),
                            if (_selecionados[item]?.codigoBarras
                                case final codigo?)
                              Text('Código: ' + codigo),
                            TextField(
                              key: ObjectKey(item),
                              controller: _controlador(
                                item,
                                previa.semQuantidade.contains(item),
                              ),
                              enabled: !_salvando,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              decoration: InputDecoration(
                                labelText: switch (item.unidade) {
                                  'cx' => 'Quantidade de caixas',
                                  'fardo' => 'Quantidade de fardos',
                                  _ => 'Quantidade de unidades soltas',
                                },
                              ),
                              onChanged: (texto) => setState(
                                () => _quantidades[item] = int.tryParse(texto),
                              ),
                            ),
                            if (buscaCatalogoDisponivel)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _salvando
                                      ? null
                                      : () => _sugerir(item),
                                  icon: const Icon(Icons.search),
                                  label: const Text('Buscar sugestão'),
                                ),
                              ),
                          ],
                        ),
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
                  onPressed:
                      _salvando ||
                          faltaConversao ||
                          faltaQuantidade ||
                          linhaIncompleta ||
                          itens.isEmpty
                      ? null
                      : () => _importar(itens),
                  child: Text(
                    _salvando
                        ? 'Importando…'
                        : 'Importar ${itens.length} produtos',
                  ),
                ),
              ),
      ),
    );
  }
}
