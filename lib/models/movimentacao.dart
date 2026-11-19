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
    required this.produtoNome,
    required this.tipo,
    required this.delta,
    required this.data,
    this.motivo,
  });

  final String id;
  final String produtoId;
  final String produtoNome;
  final TipoMovimento tipo;

  /// Variação real no estoque: positiva na entrada, negativa na saída.
  final int delta;
  final DateTime data;
  final String? motivo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'produtoId': produtoId,
        'produtoNome': produtoNome,
        'tipo': tipo.name,
        'delta': delta,
        'data': data.toIso8601String(),
        'motivo': motivo,
      };

  factory Movimentacao.fromJson(Map<String, dynamic> j) => Movimentacao(
        id: j['id'] as String,
        produtoId: j['produtoId'] as String,
        produtoNome: j['produtoNome'] as String,
        tipo: TipoMovimento.values.byName(j['tipo'] as String),
        delta: (j['delta'] as num).toInt(),
        data: DateTime.parse(j['data'] as String),
        motivo: j['motivo'] as String?,
      );
}
