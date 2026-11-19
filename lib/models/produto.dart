import 'package:stokio/utils/formatadores.dart';

enum SituacaoEstoque { normal, baixo, zerado }

enum SituacaoValidade { semData, ok, vencendo, vencido }

class Produto {
  Produto({
    required this.id,
    required this.nome,
    required this.categoria,
    required int quantidade,
    required this.minimo,
    required this.preco,
    this.custo = 0,
    this.unidade = 'un',
    this.codigoBarras,
    DateTime? validade,
    Map<DateTime?, int>? lotes,
    this.unidadesPorCaixa = 0,
    this.unidadesPorFardo = 0,
    this.local,
    this.fornecedorId,
  }) : _lotes = lotes ?? {if (quantidade > 0) validade: quantidade},
       _validadeInicial = validade;

  final String id;
  String nome;
  String categoria;
  final Map<DateTime?, int> _lotes;
  DateTime? _validadeInicial;
  int unidadesPorCaixa;
  int unidadesPorFardo;

  Map<DateTime?, int> get lotes => Map.unmodifiable(_lotes);

  int get quantidade =>
      _lotes.values.fold(0, (total, unidades) => total + unidades);

  set quantidade(int total) => alterarSaldo(total - quantidade);

  bool get estoqueEmEmbalagem => const {
    'cx',
    'caixa',
    'caixas',
    'fardo',
    'fardos',
  }.contains(unidade.trim().toLowerCase());

  int fatorEmbalagem(String tipo) {
    if (estoqueEmEmbalagem) return tipo == unidade ? 1 : 0;
    return switch (tipo) {
      'cx' => unidadesPorCaixa,
      'fardo' => unidadesPorFardo,
      _ => tipo == unidade ? 1 : 0,
    };
  }

  Map<DateTime?, int> alterarSaldo(int delta, {DateTime? vencimento}) {
    if (delta == 0) return {};
    if (delta > 0) {
      final data = vencimento == null
          ? null
          : DateTime(vencimento.year, vencimento.month, vencimento.day);
      aplicarLotes({data: delta});
      return {data: delta};
    }

    final datas = _lotes.keys.toList()
      ..sort((a, b) {
        if (a == null) return b == null ? 0 : 1;
        return b == null ? -1 : a.compareTo(b);
      });
    var restante = -delta;
    final alteracoes = <DateTime?, int>{};
    for (final data in datas) {
      if (restante == 0) break;
      final saldo = _lotes[data]!;
      final retirar = restante < saldo ? restante : saldo;
      alteracoes[data] = -retirar;
      restante -= retirar;
    }
    aplicarLotes(alteracoes);
    return alteracoes;
  }

  void aplicarLotes(Map<DateTime?, int> alteracoes) {
    for (final MapEntry(key: data, value: delta) in alteracoes.entries) {
      final saldo = (_lotes[data] ?? 0) + delta;
      if (saldo > 0) {
        _lotes[data] = saldo;
      } else {
        _lotes.remove(data);
      }
    }
  }

  void copiarLotes(Produto produto) {
    _lotes
      ..clear()
      ..addAll(produto._lotes);
  }

  int minimo;

  /// Preço de venda.
  double preco;

  /// Preço de custo (0 = não informado).
  double custo;
  String unidade;
  String? codigoBarras;
  DateTime? get validade {
    final datas = _lotes.keys.whereType<DateTime>().toList()..sort();
    return datas.isNotEmpty
        ? datas.first
        : quantidade == 0
        ? _validadeInicial
        : null;
  }

  set validade(DateTime? data) {
    if (_lotes.length > 1 || data == validade) return;
    final saldo = quantidade;
    _validadeInicial = data;
    _lotes.clear();
    if (saldo > 0) _lotes[data] = saldo;
  }

  /// Onde fica guardado: "Prateleira 2", "Freezer"...
  String? local;
  String? fornecedorId;

  SituacaoEstoque get situacao {
    if (quantidade <= 0) return SituacaoEstoque.zerado;
    if (quantidade <= minimo) return SituacaoEstoque.baixo;
    return SituacaoEstoque.normal;
  }

  /// Dias até vencer (negativo se já venceu). Nulo se não tem validade.
  int? get diasParaVencer => validade == null ? null : -diasDesde(validade!);

  SituacaoValidade situacaoValidade(int diasAviso) {
    final d = diasParaVencer;
    if (d == null) return SituacaoValidade.semData;
    if (d < 0) return SituacaoValidade.vencido;
    if (d <= diasAviso) return SituacaoValidade.vencendo;
    return SituacaoValidade.ok;
  }

  double get valorEmEstoque => quantidade * preco;

  /// Margem sobre o preço de venda (0 a 1). Nulo sem custo informado.
  double? get margem =>
      (custo > 0 && preco > 0) ? (preco - custo) / preco : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'categoria': categoria,
    'quantidade': quantidade,
    'minimo': minimo,
    'preco': preco,
    'custo': custo,
    'unidade': unidade,
    'unidadesPorCaixa': unidadesPorCaixa,
    'unidadesPorFardo': unidadesPorFardo,
    'lotes': [
      for (final MapEntry(key: data, value: saldo) in _lotes.entries)
        {'validade': data?.toIso8601String(), 'saldo': saldo},
    ],
    'codigoBarras': codigoBarras,
    'validade': validade?.toIso8601String(),
    'local': local,
    'fornecedorId': fornecedorId,
  };

  factory Produto.fromJson(Map<String, dynamic> j) => Produto(
    id: j['id'] as String,
    nome: j['nome'] as String,
    categoria: j['categoria'] as String,
    quantidade: (j['quantidade'] as num).toInt(),
    minimo: (j['minimo'] as num).toInt(),
    preco: (j['preco'] as num).toDouble(),
    custo: (j['custo'] as num?)?.toDouble() ?? 0,
    unidade: (j['unidade'] as String?) ?? 'un',
    codigoBarras: j['codigoBarras'] as String?,
    unidadesPorCaixa: (j['unidadesPorCaixa'] as num?)?.toInt() ?? 0,
    unidadesPorFardo: (j['unidadesPorFardo'] as num?)?.toInt() ?? 0,
    lotes: j['lotes'] == null
        ? null
        : {
            for (final lote in j['lotes'] as List)
              (lote['validade'] == null
                      ? null
                      : DateTime.parse(lote['validade'] as String)):
                  (lote['saldo'] as num).toInt(),
          },
    validade: j['validade'] == null
        ? null
        : DateTime.parse(j['validade'] as String),
    local: j['local'] as String?,
    fornecedorId: j['fornecedorId'] as String?,
  );
}
