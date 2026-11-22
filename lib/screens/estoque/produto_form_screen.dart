import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/catalogo_local.dart';
import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/campo_data.dart';

/// Cadastro e edição de produto.
/// Na edição a quantidade não aparece: ela muda por entradas, saídas e ajustes.
class ProdutoFormScreen extends StatefulWidget {
  const ProdutoFormScreen({super.key, this.produto, this.codigoInicial});

  final Produto? produto;

  /// Código lido pelo scanner para preencher o formulário.
  final String? codigoInicial;

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _chave = GlobalKey<FormState>();
  ProdutoCatalogo? _sugestaoCatalogo;

  @override
  void initState() {
    super.initState();
    if (widget.produto == null && _codigo.text.isNotEmpty) {
      _consultarCatalogo(_codigo.text);
    }
  }

  Future<void> _consultarCatalogo(String codigo) async {
    if (_editando) return;
    try {
      final produto = await CatalogoLocal.buscar(codigo);
      if (mounted && _codigo.text.trim() == codigo.trim()) {
        setState(() => _sugestaoCatalogo = produto);
      }
    } on Exception catch (erro) {
      debugPrint('Catálogo local indisponível: $erro');
    }
  }

  static String _dinheiro(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  late final _nome = TextEditingController(text: widget.produto?.nome ?? '');
  late final _categoria = TextEditingController(
    text: widget.produto?.categoria ?? '',
  );
  late final _codigo = TextEditingController(
    text: widget.codigoInicial ?? widget.produto?.codigoBarras ?? '',
  );
  late final _quantidade = TextEditingController();
  late final _minimo = TextEditingController(
    text: widget.produto == null ? '' : '${widget.produto!.minimo}',
  );
  late final _unidade = TextEditingController(
    text: widget.produto?.unidade ?? 'un',
  );
  late final _local = TextEditingController(text: widget.produto?.local ?? '');
  late final _preco = TextEditingController(
    text: widget.produto == null ? '' : _dinheiro(widget.produto!.preco),
  );
  late final _custo = TextEditingController(
    text: (widget.produto?.custo ?? 0) > 0
        ? _dinheiro(widget.produto!.custo)
        : '',
  );
  late final _caixa = TextEditingController(
    text: _fator(widget.produto?.unidadesPorCaixa),
  );
  late final _fardo = TextEditingController(
    text: _fator(widget.produto?.unidadesPorFardo),
  );

  String _fator(int? v) => v == null || v == 0 ? '' : v.toString();

  String? _validarFator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final tamanho = int.tryParse(v.trim());
    return tamanho == null || tamanho < 1 || tamanho > 99999
        ? 'Use um número entre 1 e 99999.'
        : null;
  }

  late DateTime? _validade = widget.produto?.validade;
  late String? _fornecedorId = widget.produto?.fornecedorId;

  bool get _editando => widget.produto != null;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _categoria,
      _codigo,
      _quantidade,
      _minimo,
      _unidade,
      _caixa,
      _fardo,
      _local,
      _preco,
      _custo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

  String? _inteiro(String? v) {
    if (v == null || v.trim().isEmpty) return 'Preencha este campo.';
    return int.tryParse(v.trim()) == null ? 'Use só números.' : null;
  }

  double? _lerValor(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  String? _valor(String? v) {
    if (v == null || v.trim().isEmpty) return 'Preencha este campo.';
    return _lerValor(v) == null ? 'Use um valor como 12,50.' : null;
  }

  String? _valorOpcional(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _lerValor(v) == null ? 'Use um valor como 8,90.' : null;
  }

  String? _validarCodigo(String? v) {
    final c = (v ?? '').trim();
    if (c.isEmpty) return null;
    return estoque.codigoEmUso(c, exceto: widget.produto?.id)
        ? 'Este código já está em outro produto.'
        : null;
  }

  Future<void> _escanear() async {
    final c = await lerCodigo(context);
    if (c == null || !mounted) return;
    setState(() {
      _codigo.text = c;
      _sugestaoCatalogo = null;
    });
    await _consultarCatalogo(c);
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;

    final preco = _lerValor(_preco.text)!;
    final custo = _lerValor(_custo.text) ?? 0.0;
    final minimo = int.parse(_minimo.text.trim());
    final codigo = _codigo.text.trim().isEmpty ? null : _codigo.text.trim();
    final local = _local.text.trim().isEmpty ? null : _local.text.trim();

    if (_editando) {
      final p = widget.produto!;
      p
        ..nome = _nome.text.trim()
        ..categoria = _categoria.text.trim()
        ..minimo = minimo
        ..unidade = _unidade.text.trim()
        ..unidadesPorCaixa = int.tryParse(_caixa.text.trim()) ?? 0
        ..unidadesPorFardo = int.tryParse(_fardo.text.trim()) ?? 0
        ..preco = preco
        ..custo = custo
        ..codigoBarras = codigo
        ..validade = _validade
        ..local = local
        ..fornecedorId = _fornecedorId;
      estoque.salvarAlteracoes(p);
    } else {
      estoque.adicionar(
        Produto(
          id: estoque.novoId(),
          nome: _nome.text.trim(),
          categoria: _categoria.text.trim(),
          quantidade: int.parse(_quantidade.text.trim()),
          minimo: minimo,
          preco: preco,
          custo: custo,
          unidade: _unidade.text.trim(),
          unidadesPorCaixa: int.tryParse(_caixa.text.trim()) ?? 0,
          unidadesPorFardo: int.tryParse(_fardo.text.trim()) ?? 0,
          codigoBarras: codigo,
          validade: _validade,
          local: local,
          fornecedorId: _fornecedorId,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final apenasNumeros = [FilteringTextInputFormatter.digitsOnly];
    final sugestoes = estoque.categorias.take(6).toList();
    final decimal = const TextInputType.numberWithOptions(decimal: true);

    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        texto,
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar produto' : 'Novo produto'),
      ),
      body: Form(
        key: _chave,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            titulo('Identificação'),
            TextFormField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Código de barras (opcional)',
                suffixIcon: IconButton(
                  tooltip: 'Escanear código de barras',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _escanear,
                ),
              ),
              validator: _validarCodigo,
              onChanged: _consultarCatalogo,
            ),
            if (_sugestaoCatalogo case final sugestao?)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Material(
                  color: AppCores.roxoSuave,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(sugestao.nome),
                    subtitle: Text('${sugestao.categoria} · catálogo local'),
                    trailing: const Icon(Icons.add),
                    onTap: () => setState(() {
                      _nome.text = sugestao.nome;
                      _categoria.text = sugestao.categoria;
                      _sugestaoCatalogo = null;
                    }),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoria,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Categoria'),
              validator: _obrigatorio,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.category_outlined),
                label: const Text('Escolher categoria'),
                onPressed: () async {
                  final selecionada = await showDialog<String>(
                    context: context,
                    builder: (dialogo) => SimpleDialog(
                      title: const Text('Categorias'),
                      children: [
                        for (final categoria in {
                          ...categoriasMercado,
                          ...estoque.categorias,
                        })
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(dialogo, categoria),
                            child: Text(categoria),
                          ),
                      ],
                    ),
                  );
                  if (selecionada != null && mounted) {
                    setState(() => _categoria.text = selecionada);
                  }
                },
              ),
            ),
            if (sugestoes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in sugestoes)
                    ActionChip(
                      label: Text(c),
                      onPressed: () => setState(() => _categoria.text = c),
                    ),
                ],
              ),
            ],
            titulo('Estoque'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_editando) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _quantidade,
                      keyboardType: TextInputType.number,
                      inputFormatters: apenasNumeros,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade atual',
                      ),
                      validator: _inteiro,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType: TextInputType.number,
                    inputFormatters: apenasNumeros,
                    decoration: const InputDecoration(
                      labelText: 'Estoque mínimo',
                    ),
                    validator: _inteiro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unidade,
                    decoration: const InputDecoration(
                      labelText: 'Unidade',
                      hintText: 'un, kg, cx',
                    ),
                    validator: _obrigatorio,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _local,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Local (opcional)',
                      hintText: 'Prateleira 2',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _caixa,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unidades por caixa',
              ),
              validator: _validarFator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fardo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unidades por fardo',
              ),
              validator: _validarFator,
            ),
            const SizedBox(height: 12),
            if ((widget.produto?.lotes.length ?? 0) <= 1)
              CampoData(
                rotulo: 'Data de validade (opcional)',
                valor: _validade,
                aoMudar: (d) => setState(() => _validade = d),
              ),
            titulo('Preços'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _custo,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                      labelText: 'Custo (opcional)',
                      prefixText: 'R\$ ',
                    ),
                    validator: _valorOpcional,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preco,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                      labelText: 'Preço de venda',
                      prefixText: 'R\$ ',
                    ),
                    validator: _valor,
                  ),
                ),
              ],
            ),
            titulo('Compras'),
            DropdownButtonFormField<String?>(
              value: _fornecedorId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fornecedor (opcional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Nenhum'),
                ),
                for (final f in estoque.fornecedores)
                  DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(f.nome, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _fornecedorId = v),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _salvar,
              child: Text(_editando ? 'Salvar alterações' : 'Salvar produto'),
            ),
          ],
        ),
      ),
    );
  }
}
