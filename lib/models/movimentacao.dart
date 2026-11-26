enum TipoMovimento { entrada, saida, ajuste, cadastro }

class Motivos {
  Motivos._();

  static const compra = 'Compra';
  static const devolucao = 'Devolução';
  static const venda = 'Venda';
  static const uso = 'Uso interno';
  static const perda = 'Perda ou vencimento';
  static const inventario = 'Inventário';
  static const outro = 'Outro';

  static const entrada = [compra, devolucao, outro];
  static const saida = [venda, uso, perda, outro];
}

class Movimentacao {
  const Movimentacao({
    required this.id,
    required this.produtoId,
    required String produtoNome,
    required this.tipo,
    required this.delta,
    required this.data,
    this.motivo,
    this.pagamento,
    this.deltaLoja,
    this.lotes = const {},
  }) : _produtoNome = produtoNome;

  final String id;
  final String produtoId;
  final String _produtoNome;
  String get produtoNome => _produtoNome.toUpperCase();
  final TipoMovimento tipo;

  /// Variação real no estoque: positiva na entrada, negativa na saída.
  final int delta;
  final DateTime data;
  final String? motivo;
  final String? pagamento;
  final int? deltaLoja;
  final Map<DateTime?, int> lotes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'produtoId': produtoId,
    'produtoNome': produtoNome,
    'tipo': tipo.name,
    'delta': delta,
    'data': data.toIso8601String(),
    'motivo': motivo,
    'pagamento': pagamento,
    'deltaLoja': deltaLoja,
    'lotes': [
      for (final MapEntry(key: data, value: qtd) in lotes.entries)
        {'validade': data?.toIso8601String(), 'delta': qtd},
    ],
  };

  factory Movimentacao.fromJson(Map<String, dynamic> j) => Movimentacao(
    id: j['id'] as String,
    produtoId: j['produtoId'] as String,
    produtoNome: j['produtoNome'] as String,
    tipo: TipoMovimento.values.byName(j['tipo'] as String),
    delta: (j['delta'] as num).toInt(),
    data: DateTime.parse(j['data'] as String),
    motivo: j['motivo'] as String?,
    pagamento: j['pagamento'] as String?,
    deltaLoja: (j['deltaLoja'] as num?)?.toInt(),
    lotes: {
      for (final lote in (j['lotes'] as List?) ?? const [])
        (lote['validade'] == null
                ? null
                : DateTime.parse(lote['validade'] as String)):
            (lote['delta'] as num).toInt(),
    },
  );
}
