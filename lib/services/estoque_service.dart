import 'package:stokio/utils/codigo_produto.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:stokio/models/fornecedor.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/importacao_estoque.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/utils/formatadores.dart';

/// Instância única usada pelas telas.
final EstoqueService estoque = EstoqueService();

class GruposAlerta {
  const GruposAlerta({
    required this.vencidos,
    required this.vencendo,
    required this.zerados,
    required this.baixos,
  });

  final List<Produto> vencidos;
  final List<Produto> vencendo;
  final List<Produto> zerados;
  final List<Produto> baixos;

  int get total =>
      vencidos.length + vencendo.length + zerados.length + baixos.length;
}

class ItemCompra {
  const ItemCompra(this.produto, this.sugerido);

  final Produto produto;
  final int sugerido;
}

class ItemVenda {
  const ItemVenda(this.produto, this.quantidade);

  final Produto produto;
  final int quantidade;
}

class EstoqueService extends ChangeNotifier {
  static const _chave = 'movimenta_estoque_v1';
  static const _limiteHistorico = 1000;

  final List<Produto> _produtos = [];
  final List<Movimentacao> _historico = [];
  final List<Fornecedor> _fornecedores = [];
  int _contador = 0;

  List<Produto> get produtos => List.unmodifiable(_produtos);
  List<Movimentacao> get historico => List.unmodifiable(_historico);
  List<Fornecedor> get fornecedores => List.unmodifiable(_fornecedores);
  int get total => _produtos.length;

  // ---------- Situações e alertas ----------

  int get _dias => perfil.diasAvisoValidade;

  List<Produto> get baixos =>
      _produtos.where((p) => p.situacao == SituacaoEstoque.baixo).toList();

  List<Produto> get zerados =>
      _produtos.where((p) => p.situacao == SituacaoEstoque.zerado).toList();

  List<Produto> _comValidade(SituacaoValidade s) {
    final lista = _produtos
        .where((p) => p.quantidade > 0 && p.situacaoValidade(_dias) == s)
        .toList();
    lista.sort((a, b) => a.validade!.compareTo(b.validade!));
    return lista;
  }

  List<Produto> get vencidos => _comValidade(SituacaoValidade.vencido);
  List<Produto> get vencendo => _comValidade(SituacaoValidade.vencendo);

  /// Cada produto aparece em um só grupo, do mais urgente para o menos.
  GruposAlerta get grupos {
    final vistos = <String>{};
    List<Produto> pegar(List<Produto> l) =>
        l.where((p) => vistos.add(p.id)).toList();
    final v = pegar(vencidos);
    final e = pegar(vencendo);
    final z = pegar(zerados);
    final b = pegar(baixos);
    return GruposAlerta(vencidos: v, vencendo: e, zerados: z, baixos: b);
  }

  List<Produto> get alertas {
    final g = grupos;
    return [...g.vencidos, ...g.vencendo, ...g.zerados, ...g.baixos];
  }

  // ---------- Consultas ----------

  Produto? _buscar(String id) {
    for (final p in _produtos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Produto? porCodigo(String codigo) {
    final c = codigoDeProduto(codigo);
    if (c == null) return null;
    for (final p in _produtos) {
      if (p.codigoBarras == c) return p;
    }
    final chave = chaveCodigoProduto(c);
    for (final p in _produtos) {
      final salvo = codigoDeProduto(p.codigoBarras);
      if (salvo != null && chaveCodigoProduto(salvo) == chave) return p;
    }
    return null;
  }

  bool codigoEmUso(String codigo, {String? exceto}) {
    final p = porCodigo(codigo);
    return p != null && p.id != exceto;
  }

  List<String> get categorias {
    final set = <String>{for (final p in _produtos) p.categoria};
    final lista = set.toList()..sort();
    return lista;
  }

  Fornecedor? fornecedorDe(Produto p) {
    final id = p.fornecedorId;
    if (id == null) return null;
    for (final f in _fornecedores) {
      if (f.id == id) return f;
    }
    return null;
  }

  int produtosDoFornecedor(Fornecedor f) =>
      _produtos.where((p) => p.fornecedorId == f.id).length;

  List<ItemCompra> get listaCompras {
    const periodo = 30;
    const diasDeReserva = 7;
    final vendas = <String, int>{};
    for (final movimento in _historico) {
      final dias = diasDesde(movimento.data);
      if (movimento.tipo == TipoMovimento.saida &&
          movimento.motivo == Motivos.venda &&
          dias >= 0 &&
          dias < periodo) {
        vendas.update(
          movimento.produtoId,
          (total) => total - movimento.delta,
          ifAbsent: () => -movimento.delta,
        );
      }
    }
    final itens = <ItemCompra>[];
    for (final produto in _produtos) {
      final prazo = fornecedorDe(produto)?.prazoDias ?? 3;
      final vendido = vendas[produto.id] ?? 0;
      final alvoPelasVendas = (vendido / periodo * (prazo + diasDeReserva))
          .ceil();
      final alvoMinimo = produto.quantidade <= produto.minimo
          ? math.max(1, produto.minimo * 2)
          : 0;
      final sugerido =
          math.max(alvoMinimo, alvoPelasVendas) - produto.quantidade;
      if (sugerido > 0) itens.add(ItemCompra(produto, sugerido));
    }
    itens.sort((a, b) => a.produto.quantidade.compareTo(b.produto.quantidade));
    return itens;
  }

  /// Produtos que mais saíram no período (e ainda têm estoque).
  List<Produto> maisVendidos({int dias = 30, int limite = 4}) {
    final mapa = <String, int>{};
    for (final m in _historico) {
      if (m.tipo != TipoMovimento.saida || diasDesde(m.data) >= dias) continue;
      mapa[m.produtoId] = (mapa[m.produtoId] ?? 0) + (-m.delta);
    }
    final ordem = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final r = <Produto>[];
    for (final e in ordem) {
      final p = _buscar(e.key);
      if (p != null && p.quantidade > 0) r.add(p);
      if (r.length == limite) break;
    }
    return r;
  }

  // ---------- Resumo ----------

  double get valorEmEstoque =>
      _produtos.fold(0.0, (soma, p) => soma + p.valorEmEstoque);

  double get custoEmEstoque =>
      _produtos.fold(0.0, (soma, p) => soma + p.quantidade * p.custo);

  /// Unidades que saíram por dia; o último item é hoje.
  List<int> saidasPorDia(int dias) {
    final r = List<int>.filled(dias, 0);
    for (final m in _historico) {
      if (m.tipo != TipoMovimento.saida) continue;
      final atras = diasDesde(m.data);
      if (atras < 0 || atras >= dias) continue;
      r[dias - 1 - atras] += -m.delta;
    }
    return r;
  }

  Iterable<Movimentacao> _saidasComMotivo(String motivo, int dias) =>
      _historico.where(
        (m) =>
            m.tipo == TipoMovimento.saida &&
            m.motivo == motivo &&
            diasDesde(m.data) < dias,
      );

  List<int> vendasPorDia(int dias) {
    final valores = List<int>.filled(dias, 0);
    for (final movimento in _saidasComMotivo(Motivos.venda, dias)) {
      final idade = diasDesde(movimento.data);
      if (idade >= 0) valores[dias - 1 - idade] -= movimento.delta;
    }
    return valores;
  }

  int perdasUnidades(int dias) => _saidasComMotivo(
    Motivos.perda,
    dias,
  ).fold(0, (soma, m) => soma + (-m.delta));

  double perdasValor(int dias) {
    var total = 0.0;
    for (final m in _saidasComMotivo(Motivos.perda, dias)) {
      final p = _buscar(m.produtoId);
      if (p != null) total += (-m.delta) * p.preco;
    }
    return total;
  }

  double receitaVendas(int dias) {
    var total = 0.0;
    for (final m in _saidasComMotivo(Motivos.venda, dias)) {
      final p = _buscar(m.produtoId);
      if (p != null) total += (-m.delta) * p.preco;
    }
    return total;
  }

  /// Só conta produtos com preço de custo informado.
  double lucroEstimado(int dias) {
    var total = 0.0;
    for (final m in _saidasComMotivo(Motivos.venda, dias)) {
      final p = _buscar(m.produtoId);
      if (p != null && p.custo > 0) total += (-m.delta) * (p.preco - p.custo);
    }
    return total;
  }

  List<MapEntry<String, int>> maisSaidas(int dias, {int limite = 5}) {
    final mapa = <String, int>{};
    for (final m in _historico) {
      if (m.tipo != TipoMovimento.saida || diasDesde(m.data) >= dias) continue;
      mapa[m.produtoNome] = (mapa[m.produtoNome] ?? 0) + (-m.delta);
    }
    final lista = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return lista.take(limite).toList();
  }

  // ---------- Alterações em produtos ----------

  String novoId() => '${DateTime.now().microsecondsSinceEpoch}_${_contador++}';

  void adicionar(Produto produto) {
    _produtos.add(produto);
    _registrar(produto, TipoMovimento.cadastro, produto.quantidade);
    _mudou();
  }

  Produto? _produtoImportacao(ItemImportado item, String unidade) {
    final chave = chaveProdutoImportado(item.nome, unidade, item.categoria);
    final encontrados = _produtos.where(
      (p) => chaveProdutoImportado(p.nome, p.unidade, p.categoria) == chave,
    );
    return encontrados.length == 1 ? encontrados.single : null;
  }

  int fatorImportacao(ItemImportado item) {
    if (!item.emEmbalagem || _produtoImportacao(item, item.unidade) != null) {
      return 1;
    }
    return item.unidadesPorEmbalagem ??
        _produtoImportacao(item, 'un')?.fatorEmbalagem(item.unidade) ??
        0;
  }

  Future<void> importarContagem(List<ItemImportado> itens) async {
    final index = <String, List<Produto>>{};
    for (final produto in _produtos) {
      final chave = chaveProdutoImportado(
        produto.nome,
        produto.unidade,
        produto.categoria,
      );
      (index[chave] ??= []).add(produto);
    }

    final alteracoes = <Produto, Produto>{};
    final novosProdutos = <Produto>[];
    final movimentos = <Movimentacao>[];
    final agora = DateTime.now();
    final destinos = <String>{};
    for (final item in itens) {
      final fator = fatorImportacao(item);
      if (fator <= 0 || item.quantidade * fator > 999999999) {
        throw StateError('Confira a conversão de embalagem de ${item.nome}.');
      }
      final unidade =
          item.emEmbalagem && _produtoImportacao(item, item.unidade) == null
          ? 'un'
          : item.unidade;
      final quantidade = item.quantidade * fator;
      final chave = chaveProdutoImportado(item.nome, unidade, item.categoria);
      if (!destinos.add(chave)) {
        throw StateError(
          'A lista tem mais de uma contagem para ${item.nome}. Revise o texto.',
        );
      }
      final semCategoria = chaveProdutoImportado(item.nome, unidade, 'Outros');
      final correspondentes = index[chave] ?? index[semCategoria];
      if (correspondentes != null && correspondentes.length > 1) {
        throw StateError(
          'Há mais de um produto chamado ${item.nome} com a mesma unidade. Revise os cadastros antes de importar.',
        );
      }
      final encontrado = item.codigoBarras == null
          ? null
          : porCodigo(item.codigoBarras!);
      if (encontrado != null && encontrado.unidade != unidade) {
        throw StateError(
          'Confira a unidade antes de importar pelo código: ' + item.nome,
        );
      }
      final anterior = encontrado ?? correspondentes?.single;
      if (encontrado == null &&
          anterior?.codigoBarras != null &&
          item.codigoBarras != null) {
        throw StateError(
          'Já existe um produto com esse nome e outro código: ' + item.nome,
        );
      }
      if (anterior != null && alteracoes.containsKey(anterior)) {
        throw StateError(
          'Há duas contagens para ' + anterior.nome + '. Revise a lista.',
        );
      }
      if (item.codigoBarras case final codigo?) {
        if (!destinos.add('gtin:' + chaveCodigoProduto(codigo))) {
          throw StateError('Há duas contagens para o mesmo código de barras.');
        }
      }
      final classificar =
          anterior != null && chave != semCategoria && index[chave] == null;
      if (classificar) index.remove(semCategoria);
      final produto = anterior == null
          ? Produto(
              id: novoId(),
              nome: item.nome,
              categoria: item.categoria,
              codigoBarras: item.codigoBarras,
              quantidade: quantidade,
              minimo: 0,
              preco: 0,
              unidade: unidade,
            )
          : Produto.fromJson(anterior.toJson());
      if (classificar) produto.categoria = item.categoria;
      produto.codigoBarras ??= item.codigoBarras;
      if (item.emEmbalagem && unidade != item.unidade) {
        if (item.unidade == 'cx') produto.unidadesPorCaixa = fator;
        if (item.unidade == 'fardo') produto.unidadesPorFardo = fator;
      }
      final delta = quantidade - (anterior?.saldoEstoque ?? 0);
      final lotes = anterior == null
          ? produto.lotes
          : produto.alterarSaldo(delta);
      if (anterior == null) {
        novosProdutos.add(produto);
      } else {
        produto.distribuirSaldo(anterior.saldoLoja);
        alteracoes[anterior] = produto;
      }
      if (anterior == null || delta != 0) {
        movimentos.add(
          Movimentacao(
            id: novoId(),
            produtoId: produto.id,
            produtoNome: produto.nome,
            tipo: anterior == null
                ? TipoMovimento.cadastro
                : TipoMovimento.ajuste,
            delta: delta,
            data: agora,
            motivo: 'Importação de estoque',
            deltaLoja: 0,
            lotes: lotes,
          ),
        );
      }
    }

    final historico = [
      ...movimentos.reversed,
      ..._historico,
    ].take(_limiteHistorico).toList();
    final dados = {
      'produtos': [
        for (final produto in _produtos)
          (alteracoes[produto] ?? produto).toJson(),
        for (final produto in novosProdutos) produto.toJson(),
      ],
      'historico': [for (final movimento in historico) movimento.toJson()],
      'fornecedores': [
        for (final fornecedor in _fornecedores) fornecedor.toJson(),
      ],
    };
    try {
      if (!await Armazenamento.gravar(_chave, jsonEncode(dados))) {
        throw StateError('Falha na gravação local.');
      }
    } catch (_) {
      throw StateError(
        'Não foi possível salvar a importação. Tente novamente.',
      );
    }
    for (final MapEntry(key: anterior, value: novo) in alteracoes.entries) {
      anterior
        ..copiarLotes(novo)
        ..unidadesPorCaixa = novo.unidadesPorCaixa
        ..unidadesPorFardo = novo.unidadesPorFardo
        ..categoria = novo.categoria
        ..codigoBarras = novo.codigoBarras;
    }
    _produtos.addAll(novosProdutos);
    _historico
      ..clear()
      ..addAll(historico);
    notifyListeners();
  }

  void salvarAlteracoes(Produto produto) => _mudou();

  void remover(Produto produto) {
    _produtos.removeWhere((p) => p.id == produto.id);
    _mudou();
  }

  // ---------- Fornecedores ----------

  void adicionarFornecedor(Fornecedor f) {
    _fornecedores.add(f);
    _mudou();
  }

  void salvarFornecedor(Fornecedor f) => _mudou();

  void removerFornecedor(Fornecedor f) {
    _fornecedores.removeWhere((x) => x.id == f.id);
    for (final p in _produtos) {
      if (p.fornecedorId == f.id) p.fornecedorId = null;
    }
    _mudou();
  }

  // ---------- Movimentações ----------

  Movimentacao? _aplicar(
    Produto produto,
    TipoMovimento tipo,
    int quantidade, {
    String? motivo,
    DateTime? validade,
    String? pagamento,
    bool? naLoja,
  }) {
    final atual = produto.quantidade;
    int delta;
    switch (tipo) {
      case TipoMovimento.entrada:
        delta = quantidade;
      case TipoMovimento.saida:
        final novo = atual - quantidade;
        delta = (novo < 0 ? 0 : novo) - atual;
      case TipoMovimento.ajuste:
        delta = quantidade - atual;
      case TipoMovimento.cadastro:
        return null;
    }
    if (quantidade < 0 || delta == 0) return null;

    final saldoLoja = produto.saldoLoja;
    final saldoArea = naLoja == true ? saldoLoja : produto.saldoEstoque;
    if (naLoja != null && delta < -saldoArea) return null;
    final lotes = produto.alterarSaldo(delta, vencimento: validade);
    if (naLoja != null) {
      produto.distribuirSaldo(
        saldoLoja + (naLoja ? delta : 0),
        preferirLoja: naLoja && produto.quantidade == 0,
      );
    }
    return _registrar(
      produto,
      tipo,
      delta,
      motivo: motivo,
      lotes: lotes,
      pagamento: pagamento,
      deltaLoja: produto.saldoLoja - saldoLoja,
    );
  }

  /// Para ajuste, [quantidade] é a contagem real (o total que existe agora).
  /// Devolve o registro criado, ou nulo se nada mudou.
  Movimentacao? movimentar(
    Produto produto,
    TipoMovimento tipo,
    int quantidade, {
    String? motivo,
    DateTime? validade,
    bool? naLoja,
  }) {
    final mov = _aplicar(
      produto,
      tipo,
      quantidade,
      motivo: motivo,
      validade: validade,
      naLoja: naLoja,
    );
    if (mov != null) _mudou();
    return mov;
  }

  /// Registra várias saídas de uma vez (venda rápida).
  List<Movimentacao> registrarVenda(
    List<ItemVenda> itens, {
    String? pagamento,
  }) {
    final quantidades = <Produto, int>{};
    for (final item in itens) {
      final produto = _buscar(item.produto.id);
      if (produto == null || item.quantidade <= 0) return [];
      final quantidade = (quantidades[produto] ?? 0) + item.quantidade;
      if (quantidade > produto.quantidade) return [];
      quantidades[produto] = quantidade;
    }

    final movs = <Movimentacao>[];
    for (final MapEntry(key: produto, value: quantidade)
        in quantidades.entries) {
      final movimento = _aplicar(
        produto,
        TipoMovimento.saida,
        quantidade,
        motivo: Motivos.venda,
        pagamento: pagamento,
      );
      if (movimento != null) movs.add(movimento);
    }
    if (movs.isNotEmpty) _mudou();
    return movs;
  }

  /// Aplica contagens do inventário. Chave = id do produto.
  List<Movimentacao> aplicarContagens(Map<String, int> contagens) {
    final movs = <Movimentacao>[];
    contagens.forEach((id, contagem) {
      final p = _buscar(id);
      if (p == null) return;
      final m = _aplicar(
        p,
        TipoMovimento.ajuste,
        contagem,
        motivo: Motivos.inventario,
      );
      if (m != null) movs.add(m);
    });
    if (movs.isNotEmpty) _mudou();
    return movs;
  }

  bool _desfazer(Movimentacao mov) {
    final i = _historico.indexWhere((m) => m.id == mov.id);
    if (i < 0) return false;
    final p = _buscar(mov.produtoId);
    final saldoLoja = p?.saldoLoja;
    final deltaLoja = mov.deltaLoja;
    if (p != null && deltaLoja != null) {
      final restaurado = saldoLoja! - deltaLoja;
      if (restaurado < 0 || restaurado > p.quantidade - mov.delta) return false;
    }
    if (p != null && mov.lotes.isNotEmpty) {
      if (mov.lotes.entries.any(
        (lote) => lote.value > (p.lotes[lote.key] ?? 0),
      )) {
        return false;
      }
      p.aplicarLotes({
        for (final lote in mov.lotes.entries) lote.key: -lote.value,
      });
    } else if (p != null) {
      final novo = p.quantidade - mov.delta;
      p.quantidade = novo < 0 ? 0 : novo;
    }
    if (p != null && deltaLoja != null) {
      p.distribuirSaldo(saldoLoja! - deltaLoja, preferirLoja: p.naLoja);
    }
    _historico.removeAt(i);
    return true;
  }

  bool desfazer(Movimentacao mov) {
    final ok = _desfazer(mov);
    if (ok) _mudou();
    return ok;
  }

  void desfazerVarias(List<Movimentacao> movs) {
    var algum = false;
    for (final m in movs) {
      if (_desfazer(m)) algum = true;
    }
    if (algum) _mudou();
  }

  Movimentacao _registrar(
    Produto produto,
    TipoMovimento tipo,
    int delta, {
    String? motivo,
    String? pagamento,
    DateTime? data,
    Map<DateTime?, int> lotes = const {},
    int? deltaLoja,
  }) {
    final mov = Movimentacao(
      id: novoId(),
      produtoId: produto.id,
      produtoNome: produto.nome,
      tipo: tipo,
      delta: delta,
      data: data ?? DateTime.now(),
      lotes: lotes,
      pagamento: pagamento,
      deltaLoja: deltaLoja,
      motivo: motivo,
    );
    _historico.insert(0, mov);
    if (_historico.length > _limiteHistorico) _historico.removeLast();
    return mov;
  }

  /// Força as telas a redesenharem (ex.: mudou o prazo de aviso de validade).
  void atualizarTela() => notifyListeners();

  void apagarTudo() {
    _produtos.clear();
    _historico.clear();
    _fornecedores.clear();
    _mudou();
  }

  // ---------- Persistência ----------

  Map<String, dynamic> toJson() => {
    'produtos': _produtos.map((p) => p.toJson()).toList(),
    'historico': _historico.map((m) => m.toJson()).toList(),
    'fornecedores': _fornecedores.map((f) => f.toJson()).toList(),
  };

  /// Valida tudo antes de trocar os dados atuais.
  void aplicarJson(Map<String, dynamic> j) {
    final ps = (j['produtos'] as List)
        .map((e) => Produto.fromJson(e as Map<String, dynamic>))
        .toList();
    final hs = (j['historico'] as List)
        .map((e) => Movimentacao.fromJson(e as Map<String, dynamic>))
        .toList();
    final fs = ((j['fornecedores'] as List?) ?? const [])
        .map((e) => Fornecedor.fromJson(e as Map<String, dynamic>))
        .toList();
    _produtos
      ..clear()
      ..addAll(ps);
    _historico
      ..clear()
      ..addAll(hs);
    _fornecedores
      ..clear()
      ..addAll(fs);
    notifyListeners();
  }

  Future<void> carregar() async {
    final texto = Armazenamento.ler(_chave);
    if (texto == null) return;
    try {
      aplicarJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      // Dados corrompidos: começa do zero.
    }
  }

  Future<void> salvar() => Armazenamento.gravar(_chave, jsonEncode(toJson()));

  void _mudou() {
    notifyListeners();
    salvar();
  }

  // ---------- Dados de exemplo ----------

  void carregarExemplo() {
    final agora = DateTime.now();
    DateTime em(int dias) => agora.add(Duration(days: dias));

    final f1 = Fornecedor(
      id: novoId(),
      nome: 'Distribuidora Boa Compra',
      telefone: '11999998888',
    );
    final f2 = Fornecedor(
      id: novoId(),
      nome: 'Laticínios da Serra',
      telefone: '11988887777',
    );
    _fornecedores.addAll([f1, f2]);

    Produto novo(
      String nome,
      String cat,
      int qtd,
      int min,
      double preco, {
      double custo = 0,
      String un = 'un',
      String? codigo,
      DateTime? validade,
      String? local,
      Fornecedor? fornecedor,
    }) {
      final p = Produto(
        id: novoId(),
        nome: nome,
        categoria: cat,
        quantidade: qtd,
        minimo: min,
        preco: preco,
        custo: custo,
        unidade: un,
        codigoBarras: codigo,
        validade: validade,
        local: local,
        fornecedorId: fornecedor?.id,
      );
      _produtos.add(p);
      return p;
    }

    void mov(
      Produto p,
      TipoMovimento t,
      int delta,
      Duration atras, [
      String? motivo,
    ]) {
      _registrar(p, t, delta, motivo: motivo, data: agora.subtract(atras));
    }

    final cafe = novo(
      'Café torrado em grão',
      'Cafés',
      24,
      10,
      38.90,
      custo: 26,
      un: 'pct',
      codigo: '7891000100103',
      validade: em(180),
      local: 'Prateleira 1',
      fornecedor: f1,
    );
    final leite = novo(
      'Leite integral 1L',
      'Laticínios',
      6,
      12,
      5.49,
      custo: 3.9,
      codigo: '7891000315507',
      validade: em(3),
      local: 'Geladeira',
      fornecedor: f2,
    );
    final acucar = novo(
      'Açúcar refinado 1kg',
      'Mercearia',
      18,
      8,
      4.99,
      custo: 3.2,
      validade: em(200),
      local: 'Prateleira 2',
      fornecedor: f1,
    );
    final copo = novo(
      'Copo descartável 200ml',
      'Descartáveis',
      0,
      50,
      0.35,
      custo: 0.2,
      local: 'Depósito',
      fornecedor: f1,
    );
    final pao = novo(
      'Pão de queijo congelado',
      'Congelados',
      9,
      10,
      29.90,
      custo: 19,
      un: 'pct',
      validade: em(20),
      local: 'Freezer',
      fornecedor: f1,
    );
    final filtro = novo(
      'Filtro de papel nº 103',
      'Descartáveis',
      40,
      15,
      7.80,
      custo: 4.5,
      un: 'cx',
      local: 'Prateleira 1',
      fornecedor: f1,
    );
    final choco = novo(
      'Chocolate em pó 200g',
      'Mercearia',
      0,
      6,
      9.90,
      custo: 6.4,
      validade: em(90),
      local: 'Prateleira 2',
      fornecedor: f1,
    );
    final agua = novo(
      'Água mineral 500ml',
      'Bebidas',
      72,
      24,
      2.50,
      custo: 1.4,
      codigo: '7894900011517',
      validade: em(300),
      local: 'Depósito',
      fornecedor: f1,
    );
    final iogurte = novo(
      'Iogurte natural 170g',
      'Laticínios',
      5,
      6,
      3.80,
      custo: 2.3,
      validade: em(-2),
      local: 'Geladeira',
      fornecedor: f2,
    );

    mov(
      leite,
      TipoMovimento.saida,
      -8,
      const Duration(days: 3, hours: 2),
      Motivos.venda,
    );
    mov(
      agua,
      TipoMovimento.entrada,
      48,
      const Duration(days: 2, hours: 5),
      Motivos.compra,
    );
    mov(
      choco,
      TipoMovimento.saida,
      -6,
      const Duration(days: 1, hours: 3),
      Motivos.venda,
    );
    mov(
      copo,
      TipoMovimento.saida,
      -120,
      const Duration(days: 1, hours: 1),
      Motivos.uso,
    );
    mov(
      iogurte,
      TipoMovimento.saida,
      -3,
      const Duration(hours: 20),
      Motivos.perda,
    );
    mov(
      cafe,
      TipoMovimento.entrada,
      12,
      const Duration(hours: 5),
      Motivos.compra,
    );
    mov(pao, TipoMovimento.saida, -4, const Duration(hours: 2), Motivos.venda);
    mov(
      acucar,
      TipoMovimento.saida,
      -2,
      const Duration(days: 4),
      Motivos.venda,
    );
    mov(
      filtro,
      TipoMovimento.saida,
      -5,
      const Duration(days: 5),
      Motivos.venda,
    );
    mov(cafe, TipoMovimento.saida, -6, const Duration(days: 2), Motivos.venda);
    mov(
      agua,
      TipoMovimento.saida,
      -14,
      const Duration(days: 1, hours: 6),
      Motivos.venda,
    );

    _historico.sort((a, b) => b.data.compareTo(a.data));
    _mudou();
  }
}
