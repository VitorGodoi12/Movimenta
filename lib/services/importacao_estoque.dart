class ItemImportado {
  const ItemImportado(
    this.nome,
    this.categoria,
    this.quantidade,
    this.unidade, {
    this.unidadesPorEmbalagem,
    this.codigoBarras,
  });

  final String nome;
  final String categoria;
  final int quantidade;
  final String unidade;
  final int? unidadesPorEmbalagem;
  final String? codigoBarras;

  ItemImportado revisar({
    int? quantidade,
    String? nome,
    String? codigoBarras,
  }) => ItemImportado(
    nome ?? this.nome,
    categoria,
    quantidade ?? this.quantidade,
    unidade,
    unidadesPorEmbalagem: unidadesPorEmbalagem,
    codigoBarras: codigoBarras ?? this.codigoBarras,
  );

  bool get emEmbalagem => unidade == 'cx' || unidade == 'fardo';

  ItemImportado comFator(int fator) => ItemImportado(
    nome,
    categoria,
    quantidade,
    unidade,
    unidadesPorEmbalagem: fator,
    codigoBarras: codigoBarras,
  );

  String get chave => chaveProdutoImportado(nome, unidade, categoria);
}

class ListaImportada {
  const ListaImportada(
    this.itens,
    this.pendencias,
    this.repetidos, {
    this.semQuantidade = const [],
  });

  final List<ItemImportado> itens;
  final List<String> pendencias;
  final List<String> repetidos;
  final List<ItemImportado> semQuantidade;
}

String _normalizar(String texto) {
  const acentos = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const simples = 'aaaaaeeeeiiiiooooouuuuc';
  return texto
      .toLowerCase()
      .replaceAllMapped(
        RegExp('[$acentos]'),
        (m) => simples[acentos.indexOf(m[0]!)],
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String chaveProdutoImportado(String nome, String unidade, String categoria) {
  final normalizado = _normalizar(nome).replaceAllMapped(
    RegExp(r'\b(269|350)\s*ml\b|\b(269|350)\b'),
    (m) => '${m[1] ?? m[2]}ml',
  );
  final secao = _normalizar(categoria);
  final grupo = _normalizar(
    _secoes[secao] ?? (secao.isEmpty ? 'Outros' : secao),
  );
  return '$normalizado|${_normalizar(unidade)}|$grupo';
}

const _bebidas = 'Bebidas';
const _limpeza = 'Produtos de limpeza';
const _salgados = 'Salgados e congelados';
const _mercearia = 'Mercearia';
const _higiene = 'Higiene';
const _laticinios = 'Laticínios';

const _secoes = {
  'bebidas': _bebidas,
  'refrigerantes': _bebidas,
  'coca': _bebidas,
  'monster': _bebidas,
  'marata & nutri': _bebidas,
  'nutri 200ml': _bebidas,
  'suco vig': _bebidas,
  'aguas': _bebidas,
  'ambev': _bebidas,
  'gatorede': _bebidas,
  'gatorade': _bebidas,
  'convencao': _bebidas,
  'cervejas': _bebidas,
  'agua sanitaria': _limpeza,
  'amaciante': _limpeza,
  'amaciantes': _limpeza,
  'detergentes': _limpeza,
  'limpeza': _limpeza,
  'produtos de limpeza': _limpeza,
  'limpeza em geral': _limpeza,
  'mercearia em geral': _mercearia,
  'papel higienico': _higiene,
  'leites': _laticinios,
  'salgados': _salgados,
  'congelados': _salgados,
};

String? _categoriaDoNome(String nome) {
  if (RegExp(r'\b(salsicha|lasanha|defumad\w*|mortadela|salgad\w*)\b')
      .hasMatch(nome)) {
    return _salgados;
  }
  if (RegExp(r'\b(qualy|margarina|leite|laticinios)\b').hasMatch(nome)) {
    return _laticinios;
  }
  if (RegExp(
    r'\b(itaipava|petra|malzembier|coca|cerveja|zero alcool|aguas?|heineken|refrigerantes?|bebidas?)\b',
  ).hasMatch(nome)) {
    return _bebidas;
  }
  return null;
}

ListaImportada interpretarListaEstoque(String texto) {
  final itens = <String, ItemImportado>{};
  final pendencias = <String>[];
  final repetidos = <String>[];
  final semQuantidade = <ItemImportado>[];
  String? categoria;
  String? marca;
  String? volumeAgua;
  var emAguas = false;
  final linhaItem = RegExp(
    r'^(\d+|o(?=\s*[x×]))(?:\s*[x×]\s*|\s+|(?=(?:cx|caixas?|fr|fardos?|un)\s))(?:(cx|caixas?|fr|fardos?|un)\s+)?(.+)$',
    caseSensitive: false,
  );
  final volume = RegExp(
    r'^\d+(?:[,.]\d+)?\s*(?:ml|l|litros?)$',
    caseSensitive: false,
  );
  for (final original
      in texto.replaceAll('&#x20;', ' ').split(RegExp(r'\r?\n'))) {
    final linha = original
        .replaceAll(r'\*', '*')
        .replaceAll(RegExp(r'\\+$'), '')
        .trim()
        .replaceAll(RegExp(r'^[*•\s]+|[*\s]+$'), '');
    if (linha.isEmpty || RegExp(r'^\\?-{3,}$').hasMatch(linha)) continue;

    final entreChaves = linha.startsWith('{') && linha.endsWith('}');
    final titulo = entreChaves
        ? linha.substring(1, linha.length - 1).trim()
        : linha;
    final normalizado = _normalizar(titulo);
    if (normalizado == 'novo estoque' || normalizado == 'nao tem nada') {
      continue;
    }
    if (volume.hasMatch(normalizado)) {
      if (emAguas) volumeAgua = titulo;
      continue;
    }

    final secao =
        _secoes[normalizado] ??
        (normalizado.startsWith('sabao') ? _limpeza : null);
    if (secao != null || entreChaves) {
      categoria = secao ?? titulo;
      emAguas = normalizado == 'aguas';
      volumeAgua = null;
      marca = switch (normalizado) {
        'monster' => 'Monster',
        'marata & nutri' => 'Maratá & Nutri',
        'nutri 200ml' => 'Nutri 200ml',
        'suco vig' => 'Suco Vig',
        'gatorede' || 'gatorade' => 'Gatorade',
        _ => null,
      };
      continue;
    }

    final campos = linhaItem.firstMatch(linha);
    final quantidadeBruta = campos?[1];
    final quantidade = quantidadeBruta?.toLowerCase() == 'o'
        ? 0
        : int.tryParse(quantidadeBruta ?? '');
    if (campos == null || quantidade == null || quantidade > 999999999) {
      semQuantidade.add(
        ItemImportado(
          campos?[3]?.trim() ?? linha,
          categoria ?? _categoriaDoNome(normalizado) ?? 'Outros',
          0,
          'un',
        ),
      );
      pendencias.add(linha);
      continue;
    }
    var nome = campos[3]!.trim();
    if (RegExp(
      r'^(?:x|×|cx|caixas?|fr|fardos?|un)?$',
      caseSensitive: false,
    ).hasMatch(nome)) {
      pendencias.add(linha);
      continue;
    }

    final embalagem = switch (_normalizar(campos[2] ?? '')) {
      'cx' || 'caixa' || 'caixas' => 'cx',
      'fr' || 'fardo' || 'fardos' => 'fardo',
      _ => 'un',
    };
    if (_normalizar(nome) == 'zero alcool it') nome = 'Itaipava sem álcool';
    final sugestao = _categoriaDoNome(_normalizar(nome));
    final categoriaItem = sugestao == _salgados || sugestao == _laticinios
        ? sugestao!
        : categoria ?? sugestao ?? 'Outros';
    if (marca != null && !_normalizar(nome).startsWith(_normalizar(marca))) {
      nome = '$marca $nome';
    }
    if (emAguas &&
        volumeAgua != null &&
        !_normalizar(nome).contains(_normalizar(volumeAgua))) {
      nome = '$nome $volumeAgua';
    }
    final item = ItemImportado(nome, categoriaItem, quantidade, embalagem);
    final anterior = itens[item.chave];
    if (anterior != null) {
      repetidos.add('${anterior.nome} (${anterior.quantidade} → $quantidade)');
    }
    itens[item.chave] = item;
  }
  return ListaImportada(
    itens.values.toList(),
    pendencias,
    repetidos,
    semQuantidade: semQuantidade,
  );
}
