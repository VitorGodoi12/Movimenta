import 'package:stokio/utils/formatadores.dart';

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
    this.custo = 0,
    this.unidade = 'un',
    this.codigoBarras,
    this.validade,
    this.local,
    this.fornecedorId,
  });

  final String id;
  String nome;
  String categoria;
  int quantidade;
  int minimo;

  /// Preço de venda.
  double preco;

  /// Preço de custo (0 = não informado).
  double custo;
  String unidade;
  String? codigoBarras;
  DateTime? validade;

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
        validade: j['validade'] == null
            ? null
            : DateTime.parse(j['validade'] as String),
        local: j['local'] as String?,
        fornecedorId: j['fornecedorId'] as String?,
      );
}
