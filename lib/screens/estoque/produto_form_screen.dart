import 'package:stokio/widgets/cartao_painel.dart';
import 'package:stokio/utils/codigo_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/catalogo_local.dart';
import 'package:stokio/services/open_food_facts_web.dart'
    if (dart.library.io) 'package:stokio/services/open_food_facts.dart';
import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/campo_data.dart';
import 'package:stokio/widgets/buscar_catalogo.dart';

/// Cadastro e edição de produto.
/// Na edição a quantidade não aparece: ela muda por entradas, saídas e ajustes.
class ProdutoFormScreen extends StatefulWidget {
  const ProdutoFormScreen({
    super.key,
    this.produto,
    this.codigoInicial,
    this.vincularProduto,
    this.lojaInicial = false,
  });

  final bool lojaInicial;
  final Produto? produto;

  /// Código lido pelo scanner para preencher o formulário.
  final String? codigoInicial;
  final Future<Produto?> Function(BuildContext)? vincularProduto;

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _chave = GlobalKey<FormState>();
  ProdutoCatalogo? _sugestaoCatalogo;
  String? _marcaCatalogo;
  String? _mensagemConsulta;
  bool _buscandoCatalogo = false;
  String _fonteCatalogo = 'Catálogo local';
  int _consultaCatalogo = 0;
  String? _codigoConsultado;
  String? _nomeAutomatico;
  String? _categoriaAutomatica;

  @override
  void initState() {
    super.initState();
    if (widget.produto == null && _codigo.text.isNotEmpty) {
      _consultarCatalogo(_codigo.text, online: true);
    }
  }

  bool get _podeBuscarOnline =>
      OpenFoodFacts.disponivel &&
      !_editando &&
      eGtin(_codigo.text.trim()) &&
      estoque.porCodigo(_codigo.text) == null;

  void _preencherAutomaticamente(ProdutoCatalogo produto) {
    if (_nome.text.trim().isEmpty) {
      _nomeAutomatico = CatalogoLocal.formatarNome(produto.nome);
      _nome.text = _nomeAutomatico!;
    }
    if (_categoria.text.trim().isEmpty) {
      _categoriaAutomatica = produto.categoria;
      _categoria.text = _categoriaAutomatica!;
    }
  }

  Future<void> _consultarCatalogo(String codigo, {bool online = false}) async {
    if (_editando) return;
    codigo = codigo.trim();
    final consulta = ++_consultaCatalogo;
    final gtin = eGtin(codigo);
    final buscarOnline =
        online &&
        OpenFoodFacts.disponivel &&
        gtin &&
        estoque.porCodigo(codigo) == null;
    setState(() {
      if (_codigoConsultado != codigo) {
        if (_nome.text == _nomeAutomatico) _nome.clear();
        if (_categoria.text == _categoriaAutomatica) _categoria.clear();
        _nomeAutomatico = null;
        _categoriaAutomatica = null;
        _codigoConsultado = codigo;
      }
      _sugestaoCatalogo = null;
      _mensagemConsulta = null;
      _marcaCatalogo = null;
      _fonteCatalogo = 'Catálogo local';
      _buscandoCatalogo = buscarOnline;
    });

    if (!gtin || estoque.porCodigo(codigo) != null) return;
    ProdutoCatalogo? local;
    try {
      local = await CatalogoLocal.buscar(codigo);
    } on Exception catch (erro) {
      debugPrint('Catálogo local indisponível: $erro');
    }
    if (!mounted || consulta != _consultaCatalogo) return;

    if (local != null) {
      setState(() {
        _sugestaoCatalogo = local;
        _buscandoCatalogo = false;
        _preencherAutomaticamente(local!);
      });
      return;
    }
    if (!buscarOnline) return;

    try {
      final sugestao = await OpenFoodFacts.buscar(codigo);
      if (!mounted || consulta != _consultaCatalogo) return;
      setState(() {
        _buscandoCatalogo = false;
        if (sugestao == null) {
          _mensagemConsulta =
              'Produto não encontrado. Complete o cadastro manualmente.';
          return;
        }
        final produto = (nome: sugestao.nome, categoria: sugestao.categoria);
        _sugestaoCatalogo = produto;
        _marcaCatalogo = sugestao.marca;
        _fonteCatalogo = sugestao.fonte;
        _preencherAutomaticamente(produto);
      });
    } on Exception {
      if (!mounted || consulta != _consultaCatalogo) return;
      setState(() {
        _buscandoCatalogo = false;
        _mensagemConsulta =
            'Consulta indisponível. Complete o cadastro ou tente novamente.';
      });
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
  late final _quantidade = TextEditingController(
    text: widget.produto?.saldoEstoque.toString(),
  );
  late final _quantidadeLoja = TextEditingController(
    text: widget.produto?.saldoLoja.toString(),
  );
  DateTime? _validadeInicial;
  bool _semValidade = false;
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

  late Set<bool> _areas = {
    if (widget.produto == null
        ? !widget.lojaInicial
        : widget.produto!.saldoEstoque > 0 || !widget.produto!.naLoja)
      false,
    if (widget.produto == null
        ? widget.lojaInicial
        : widget.produto!.saldoLoja > 0 ||
              widget.produto!.naLoja && widget.produto!.quantidade == 0)
      true,
  };
  late final _lotes = [
    for (final lote in (widget.produto?.lotes ?? <DateTime?, int>{}).entries)
      if (lote.key != null) _LoteEditavel(lote.key, lote.value),
  ];
  late String? _fornecedorId = widget.produto?.fornecedorId;

  bool get _editando => widget.produto != null;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _categoria,
      _codigo,
      _quantidade,
      _quantidadeLoja,
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
    if (codigoDeProduto(c) == null) {
      return 'Use o código da embalagem, sem link.';
    }
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
    await _consultarCatalogo(c, online: true);
  }

  void _aplicarSugestao(ProdutoCatalogo sugestao) {
    setState(() {
      _nome.text = CatalogoLocal.formatarNome(sugestao.nome);
      _categoria.text = sugestao.categoria;
      _sugestaoCatalogo = null;
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;

    final preco = _lerValor(_preco.text)!;
    final custo = _lerValor(_custo.text) ?? 0.0;
    final minimo = int.parse(_minimo.text.trim());
    final codigo = codigoDeProduto(_codigo.text);
    final local = _local.text.trim().isEmpty ? null : _local.text.trim();

    final naLoja = _areas.contains(true);
    final noEstoque = _areas.contains(false);
    final saldoLoja = naLoja ? int.parse(_quantidadeLoja.text.trim()) : 0;
    final saldoEstoque = noEstoque ? int.parse(_quantidade.text.trim()) : 0;
    final total = saldoLoja + saldoEstoque;
    if (_editando && total != widget.produto!.quantidade) {
      _aviso(
        'Mantenha o saldo total para transferir. Use Entrada ou Saída para mudar a quantidade.',
      );
      return;
    }
    if (!_editando && !_semValidade && _validadeInicial == null) {
      _aviso('Informe a validade ou marque que o produto não tem validade.');
      return;
    }
    final lotes = <DateTime?, int>{};
    var semData = total;
    for (final lote in _lotes) {
      if (lote.data == null ||
          lote.quantidade <= 0 ||
          lote.quantidade > semData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe a data e a quantidade de cada lote. A soma dos lotes deve caber no saldo.',
            ),
          ),
        );
        return;
      }
      lotes.update(
        lote.data,
        (saldo) => saldo + lote.quantidade,
        ifAbsent: () => lote.quantidade,
      );
      semData -= lote.quantidade;
    }
    if (semData > 0) {
      final data = _editando || _semValidade ? null : _validadeInicial;
      lotes.update(data, (saldo) => saldo + semData, ifAbsent: () => semData);
    }

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
        ..definirLotes(lotes)
        ..distribuirSaldo(saldoLoja, preferirLoja: naLoja && !noEstoque)
        ..local = local
        ..fornecedorId = _fornecedorId;
      estoque.salvarAlteracoes(p);
    } else {
      estoque.adicionar(
        Produto(
          id: estoque.novoId(),
          nome: _nome.text.trim(),
          categoria: _categoria.text.trim(),
          quantidade: total,
          minimo: minimo,
          preco: preco,
          custo: custo,
          unidade: _unidade.text.trim(),
          unidadesPorCaixa: int.tryParse(_caixa.text.trim()) ?? 0,
          unidadesPorFardo: int.tryParse(_fardo.text.trim()) ?? 0,
          codigoBarras: codigo,
          lotes: lotes,
          naLoja: naLoja,
          saldoLoja: saldoLoja,
          local: local,
          fornecedorId: _fornecedorId,
        ),
      );
    }
    if (codigo != null) {
      CatalogoLocal.recordar(codigo, (
        nome: _nome.text.trim(),
        categoria: _categoria.text.trim(),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final apenasNumeros = [FilteringTextInputFormatter.digitsOnly];
    final sugestoes = estoque.categorias.take(6).toList();
    final decimal = const TextInputType.numberWithOptions(decimal: true);

    Widget secao(IconData icone, String titulo, List<Widget> campos) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CartaoPainel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, color: context.cores.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...campos,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar produto' : 'Novo produto'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: FilledButton.icon(
          onPressed: _salvar,
          icon: const Icon(Icons.check),
          label: Text(_editando ? 'Salvar alterações' : 'Salvar produto'),
        ),
      ),
      body: Form(
        key: _chave,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              secao(Icons.inventory_2_outlined, 'Identificação', [
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
                  onChanged: (leitura) {
                    final codigo = codigoDeProduto(leitura);
                    if (codigo != null && codigo != leitura.trim()) {
                      _codigo.value = TextEditingValue(
                        text: codigo,
                        selection: TextSelection.collapsed(
                          offset: codigo.length,
                        ),
                      );
                    }
                    _consultarCatalogo(codigo ?? leitura);
                  },
                ),
                if (_buscandoCatalogo)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Consultando catálogo',
                    ),
                  )
                else if (_podeBuscarOnline && _sugestaoCatalogo == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          _consultarCatalogo(_codigo.text, online: true),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar no catálogo online'),
                    ),
                  ),
                if (widget.vincularProduto != null)
                  TextButton(
                    onPressed: () async {
                      final codigo = codigoDeProduto(_codigo.text);
                      if (codigo == null) return;
                      final produto = await widget.vincularProduto!(context);
                      if (!mounted || produto == null) return;
                      Navigator.pushReplacement<void, void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProdutoFormScreen(
                            produto: produto,
                            codigoInicial: codigo,
                          ),
                        ),
                      );
                    },
                    child: const Text('Vincular a produto sem código'),
                  ),
                if (_mensagemConsulta != null) Text(_mensagemConsulta!),
                if (_sugestaoCatalogo case final sugestao?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Material(
                      color: context.cores.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(sugestao.nome),
                        subtitle: Text(
                          [
                            if (_marcaCatalogo != null) _marcaCatalogo!,
                            sugestao.categoria,
                            _fonteCatalogo,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.add),
                        onTap: () => setState(() {
                          _nome.text = CatalogoLocal.formatarNome(
                            sugestao.nome,
                          );
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
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                  ),
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
                                onPressed: () =>
                                    Navigator.pop(dialogo, categoria),
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
                if (buscaCatalogoDisponivel)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.manage_search_outlined),
                      label: const Text('Buscar produto pelo nome'),
                      onPressed: () async {
                        final nome = _nome.text.trim();
                        if (nome.length < 3) {
                          _aviso(
                            'Digite pelo menos três letras no nome do produto.',
                          );
                          return;
                        }
                        final sugestao = await buscarNoCatalogo(context, nome);
                        if (sugestao == null || !mounted) return;
                        _aplicarSugestao((
                          nome: sugestao.nome,
                          categoria: sugestao.categoria,
                        ));
                        if (_codigo.text.trim().isEmpty)
                          _codigo.text = sugestao.codigo;
                      },
                    ),
                  ),
              ]),
              secao(Icons.swap_horiz_rounded, 'Quantidades e destino', [
                SegmentedButton<bool>(
                  multiSelectionEnabled: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Estoque'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.storefront_outlined),
                      label: Text('Loja'),
                    ),
                  ],
                  selected: _areas,
                  onSelectionChanged: (areas) => setState(() {
                    _areas = areas;
                    if (_editando && areas.length == 1) {
                      final campo = areas.single
                          ? _quantidadeLoja
                          : _quantidade;
                      campo.text = widget.produto!.quantidade.toString();
                    }
                  }),
                ),
                const SizedBox(height: 12),
                if (_editando)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Saldo total: ' + widget.produto!.quantidade.toString(),
                        style: t.titleLarge,
                      ),
                    ),
                  ),
                for (final (area, controle, rotulo) in [
                  (false, _quantidade, 'Quantidade no estoque'),
                  (true, _quantidadeLoja, 'Quantidade na loja'),
                ])
                  if (_areas.contains(area))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controle,
                        keyboardType: TextInputType.number,
                        inputFormatters: apenasNumeros,
                        decoration: InputDecoration(labelText: rotulo),
                        validator: _inteiro,
                      ),
                    ),
                TextFormField(
                  controller: _minimo,
                  keyboardType: TextInputType.number,
                  inputFormatters: apenasNumeros,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade mínima',
                  ),
                  validator: _inteiro,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unidade.text,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Embalagem',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'un',
                            child: Text('Solto'),
                          ),
                          const DropdownMenuItem(
                            value: 'cx',
                            child: Text('Caixa'),
                          ),
                          const DropdownMenuItem(
                            value: 'fardo',
                            child: Text('Fardo'),
                          ),
                          if (!const {
                            'un',
                            'cx',
                            'fardo',
                          }.contains(_unidade.text))
                            DropdownMenuItem(
                              value: _unidade.text,
                              child: Text(_unidade.text),
                            ),
                        ],
                        onChanged: (unidade) {
                          if (unidade != null)
                            setState(() => _unidade.text = unidade);
                        },
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
                    labelText: 'Unidades por caixa (opcional)',
                  ),
                  validator: _validarFator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fardo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unidades por fardo (opcional)',
                  ),
                  validator: _validarFator,
                ),
                const SizedBox(height: 12),
              ]),
              secao(Icons.event_outlined, 'Lotes e validades', [
                if (!_editando) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Produto sem validade'),
                    value: _semValidade,
                    onChanged: (valor) =>
                        setState(() => _semValidade = valor ?? false),
                  ),
                  if (!_semValidade)
                    CampoData(
                      rotulo: 'Validade principal',
                      valor: _validadeInicial,
                      aoMudar: (data) => _validadeInicial = data,
                    ),
                ],
                const Text(
                  'Se houver datas diferentes, informe a quantidade de cada lote adicional.',
                ),
                const SizedBox(height: 12),
                for (final lote in _lotes)
                  Card(
                    key: ObjectKey(lote),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          CampoData(
                            rotulo: 'Validade do lote',
                            valor: lote.data,
                            aoMudar: (data) {
                              if (mounted) setState(() => lote.data = data);
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: lote.quantidade == 0
                                      ? ''
                                      : lote.quantidade.toString(),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: apenasNumeros,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade do lote',
                                  ),
                                  onChanged: (texto) => lote.quantidade =
                                      int.tryParse(texto) ?? 0,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remover validade do lote',
                                onPressed: () =>
                                    setState(() => _lotes.remove(lote)),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _lotes.add(_LoteEditavel(null, 0))),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar validade'),
                ),
              ]),
              secao(Icons.sell_outlined, 'Preços', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _custo,
                        keyboardType: decimal,
                        decoration: const InputDecoration(
                          labelText: 'Preço de compra',
                          prefixText: 'R\$ ',
                        ),
                        validator: _editando ? _valorOpcional : _valor,
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
              ]),
              secao(Icons.local_shipping_outlined, 'Compras', [
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
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoteEditavel {
  _LoteEditavel(this.data, this.quantidade);

  DateTime? data;
  int quantidade;
}
