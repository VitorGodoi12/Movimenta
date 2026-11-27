typedef LoteMercado = ({DateTime? validade, int quantidade, bool naLoja});

class EntradaMercado {
  const EntradaMercado({
    required this.codigo,
    required this.nome,
    required this.categoria,
    required this.unidade,
    required this.preco,
    required this.lotes,
    required this.publicarNoCatalogo,
  });

  final String? codigo;
  final String nome;
  final String categoria;
  final String unidade;
  final double preco;
  final List<LoteMercado> lotes;
  final bool publicarNoCatalogo;

  Map<String, dynamic> paraDados() => {
    'codigoBarras': codigo,
    'nome': nome,
    'categoria': categoria,
    'unidade': unidade,
    'preco': preco,
    'publicarNoCatalogo': publicarNoCatalogo,
    'lotes': [
      for (final lote in lotes)
        {
          'quantidade': lote.quantidade,
          'validade': lote.validade?.toIso8601String(),
          'destino': lote.naLoja ? 'loja' : 'estoque',
        },
    ],
  };
}
