import 'package:movimenta/utils/formatadores.dart';

enum SituacaoEstoque { normal, baixo, zerado }

enum SituacaoValidade { semData, ok, vencendo, vencido }

class Produto {
  Produto({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.quantidade,
    required this.minimo,
    required this.preco,
    this.unidade = 'un',
    this.codigoBarras,
    this.validade,
  });

  final String id;
  String nome;
  String categoria;
  int quantidade;
  int minimo;
  double preco;
  String unidade;
  String? codigoBarras;
  DateTime? validade;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'categoria': categoria,
        'quantidade': quantidade,
        'minimo': minimo,
        'preco': preco,
        'unidade': unidade,
        'codigoBarras': codigoBarras,
        'validade': validade?.toIso8601String(),
      };

  factory Produto.fromJson(Map<String, dynamic> j) => Produto(
        id: j['id'] as String,
        nome: j['nome'] as String,
        categoria: j['categoria'] as String,
        quantidade: (j['quantidade'] as num).toInt(),
        minimo: (j['minimo'] as num).toInt(),
        preco: (j['preco'] as num).toDouble(),
        unidade: (j['unidade'] as String?) ?? 'un',
        codigoBarras: j['codigoBarras'] as String?,
        validade: j['validade'] == null
            ? null
            : DateTime.parse(j['validade'] as String),
      );
}
