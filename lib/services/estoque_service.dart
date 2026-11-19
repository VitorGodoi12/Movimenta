import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movimenta/models/movimentacao.dart';
import 'package:movimenta/models/produto.dart';
import 'package:movimenta/services/armazenamento.dart';
import 'package:movimenta/services/importacao_estoque.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/utils/formatadores.dart';

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

class EstoqueService extends ChangeNotifier {
  static const _chave = 'movimenta_estoque_v1';
  static const _limiteHistorico = 1000;

  final List<Produto> _produtos = [];
  final List<Movimentacao> _historico = [];
  int _contador = 0;

  List<Produto> get produtos => List.unmodifiable(_produtos);
  List<Movimentacao> get historico => List.unmodifiable(_historico);
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
    final c = codigo.trim();
    if (c.isEmpty) return null;
    for (final p in _produtos) {
      if (p.codigoBarras == c) return p;
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

  List<ItemCompra> get listaCompras {
    final itens = <ItemCompra>[];
    for (final p in _produtos) {
      if (p.quantidade <= p.minimo) {
        var sugerido = p.minimo * 2 - p.quantidade;
        if (sugerido < 1) sugerido = 1;
        itens.add(ItemCompra(p, sugerido));
      }
    }
    itens.sort((a, b) => a.produto.quantidade.compareTo(b.produto.quantidade));
    return itens;
  }

  // ---------- Resumo ----------

  double get valorEmEstoque =>
      _produtos.fold(0.0, (soma, p) => soma + p.valorEmEstoque);

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

  Iterable<Movimentacao> _perdas(int dias) => _historico.where((m) =>
      m.tipo == TipoMovimento.saida &&
      m.motivo == Motivos.perda &&
      diasDesde(m.data) < dias);

  int perdasUnidades(int dias) =>
      _perdas(dias).fold(0, (soma, m) => soma + (-m.delta));

  double perdasValor(int dias) {
    var total = 0.0;
    for (final m in _perdas(dias)) {
      final p = _buscar(m.produtoId);
      if (p != null) total += (-m.delta) * p.preco;
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

  // ---------- Alterações ----------

  String novoId() => '${DateTime.now().microsecondsSinceEpoch}_${_contador++}';

  void adicionar(Produto produto) {
    _produtos.add(produto);
    _registrar(produto, TipoMovimento.cadastro, produto.quantidade);
    _mudou();
  }

  Future<void> importarContagem(List<ItemImportado> itens) async {
    final index = <String, List<Produto>>{};
    for (final produto in _produtos) {
      final chave = chaveProdutoImportado(
        produto.nome, produto.unidade, produto.categoria,
      );
      (index[chave] ??= []).add(produto);
    }

    final alteracoes = <Produto, Produto>{};
    final novosProdutos = <Produto>[];
    final movimentos = <Movimentacao>[];
    final agora = DateTime.now();
    for (final item in itens) {
      final semCategoria = chaveProdutoImportado(
        item.nome, item.unidade, 'Outros',
      );
      final correspondentes = index[item.chave] ?? index[semCategoria];
      if (correspondentes != null && correspondentes.length > 1) {
        throw StateError(
          'Há mais de um produto chamado ${item.nome} com a mesma unidade. Revise os cadastros antes de importar.',
        );
      }
      final anterior = correspondentes?.single;
      final classificar = anterior != null
          && item.chave != semCategoria
          && index[item.chave] == null;
      if (classificar) index.remove(semCategoria);
      final produto = anterior == null
          ? Produto(
              id: novoId(),
              nome: item.nome,
              categoria: item.categoria,
              quantidade: item.quantidade,
              minimo: 0,
              preco: 0,
              unidade: item.unidade,
            )
          : (Produto.fromJson(anterior.toJson())..quantidade = item.quantidade);
      if (classificar) produto.categoria = item.categoria;
      if (anterior == null) {
        novosProdutos.add(produto);
      } else {
        alteracoes[anterior] = produto;
      }
      final delta = item.quantidade - (anterior?.quantidade ?? 0);
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
        ..quantidade = novo.quantidade
        ..categoria = novo.categoria;
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

  /// Para ajuste, [quantidade] é a contagem real (o total que existe agora).
  /// Devolve o registro criado, ou nulo se nada mudou.
  Movimentacao? movimentar(
    Produto produto,
    TipoMovimento tipo,
    int quantidade, {
    String? motivo,
    DateTime? validade,
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
    if (delta == 0) return null;

    produto.quantidade = atual + delta;

    if (tipo == TipoMovimento.entrada && validade != null) {
      // Guarda sempre a validade mais próxima do que está na prateleira.
      final antiga = produto.validade;
      if (antiga == null || atual <= 0 || validade.isBefore(antiga)) {
        produto.validade = validade;
      }
    }

    final mov = _registrar(produto, tipo, delta, motivo: motivo);
    _mudou();
    return mov;
  }

  bool desfazer(Movimentacao mov) {
    final i = _historico.indexWhere((m) => m.id == mov.id);
    if (i < 0) return false;
    final p = _buscar(mov.produtoId);
    if (p != null) {
      final novo = p.quantidade - mov.delta;
      p.quantidade = novo < 0 ? 0 : novo;
    }
    _historico.removeAt(i);
    _mudou();
    return true;
  }

  Movimentacao _registrar(
    Produto produto,
    TipoMovimento tipo,
    int delta, {
    String? motivo,
    DateTime? data,
  }) {
    final mov = Movimentacao(
      id: novoId(),
      produtoId: produto.id,
      produtoNome: produto.nome,
      tipo: tipo,
      delta: delta,
      data: data ?? DateTime.now(),
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
    _mudou();
  }

  // ---------- Persistência ----------

  Map<String, dynamic> toJson() => {
        'produtos': _produtos.map((p) => p.toJson()).toList(),
        'historico': _historico.map((m) => m.toJson()).toList(),
      };

  /// Valida tudo antes de trocar os dados atuais.
  void aplicarJson(Map<String, dynamic> j) {
    final ps = (j['produtos'] as List)
        .map((e) => Produto.fromJson(e as Map<String, dynamic>))
        .toList();
    final hs = (j['historico'] as List)
        .map((e) => Movimentacao.fromJson(e as Map<String, dynamic>))
        .toList();
    _produtos
      ..clear()
      ..addAll(ps);
    _historico
      ..clear()
      ..addAll(hs);
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

    Produto novo(String nome, String cat, int qtd, int min, double preco,
        {String un = 'un', String? codigo, DateTime? validade}) {
      final p = Produto(
        id: novoId(),
        nome: nome,
        categoria: cat,
        quantidade: qtd,
        minimo: min,
        preco: preco,
        unidade: un,
        codigoBarras: codigo,
        validade: validade,
      );
      _produtos.add(p);
      return p;
    }

    void mov(Produto p, TipoMovimento t, int delta, Duration atras,
        [String? motivo]) {
      _registrar(p, t, delta, motivo: motivo, data: agora.subtract(atras));
    }

    final cafe = novo('Café torrado em grão', 'Cafés', 24, 10, 38.90,
        un: 'pct', codigo: '7891000100103', validade: em(180));
    final leite = novo('Leite integral 1L', 'Laticínios', 6, 12, 5.49,
        codigo: '7891000315507', validade: em(3));
    final acucar = novo('Açúcar refinado 1kg', 'Mercearia', 18, 8, 4.99,
        validade: em(200));
    final copo = novo('Copo descartável 200ml', 'Descartáveis', 0, 50, 0.35);
    final pao = novo('Pão de queijo congelado', 'Congelados', 9, 10, 29.90,
        un: 'pct', validade: em(20));
    final filtro = novo('Filtro de papel nº 103', 'Descartáveis', 40, 15, 7.80,
        un: 'cx');
    final choco = novo('Chocolate em pó 200g', 'Mercearia', 0, 6, 9.90,
        validade: em(90));
    final agua = novo('Água mineral 500ml', 'Bebidas', 72, 24, 2.50,
        codigo: '7894900011517', validade: em(300));
    final iogurte = novo('Iogurte natural 170g', 'Laticínios', 5, 6, 3.80,
        validade: em(-2));

    mov(leite, TipoMovimento.saida, -8, const Duration(days: 3, hours: 2),
        Motivos.venda);
    mov(agua, TipoMovimento.entrada, 48, const Duration(days: 2, hours: 5),
        Motivos.compra);
    mov(choco, TipoMovimento.saida, -6, const Duration(days: 1, hours: 3),
        Motivos.venda);
    mov(copo, TipoMovimento.saida, -120, const Duration(days: 1, hours: 1),
        Motivos.uso);
    mov(iogurte, TipoMovimento.saida, -3, const Duration(hours: 20),
        Motivos.perda);
    mov(cafe, TipoMovimento.entrada, 12, const Duration(hours: 5),
        Motivos.compra);
    mov(pao, TipoMovimento.saida, -4, const Duration(hours: 2), Motivos.venda);
    mov(acucar, TipoMovimento.saida, -2, const Duration(days: 4),
        Motivos.venda);
    mov(filtro, TipoMovimento.saida, -5, const Duration(days: 5),
        Motivos.venda);

    _historico.sort((a, b) => b.data.compareTo(a.data));
    _mudou();
  }
}
