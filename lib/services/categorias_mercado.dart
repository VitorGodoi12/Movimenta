const categoriasMercado = [
  'Refrigerantes',
  'Águas',
  'Sucos',
  'Energéticos',
  'Cervejas',
  'Leites',
  'Laticínios',
  'Frios',
  'Salgados e congelados',
  'Arroz',
  'Feijão',
  'Massas',
  'Cafés',
  'Biscoitos',
  'Chocolates',
  'Mercearia',
  'Detergentes',
  'Água sanitária',
  'Amaciantes',
  'Sabão em pó',
  'Produtos de limpeza',
  'Papel higiênico',
  'Higiene',
  'Outros',
];

String categoriaExibida(String nome, String categoria) {
  final atual = categoria.trim();
  final texto = nome.toLowerCase();
  if (atual == 'Bebidas' || atual == 'Outros' || atual.isEmpty) {
    if (RegExp(
      r'\b(coca|fanta|sprit\w*|guaran[aá]|kuat|sukita|pepsi|refrigerante)\b',
    ).hasMatch(texto))
      return 'Refrigerantes';
    if (RegExp(r'\b(itaipava|petra|heineken|brahma|skol|cerveja)\b')
        .hasMatch(texto))
      return 'Cervejas';
    if (RegExp(r'\b(monster|red bull|energ[eé]tico)\b').hasMatch(texto))
      return 'Energéticos';
    if (RegExp(r'\b(suco|del+\s*vale|kapo|nutri)\b').hasMatch(texto))
      return 'Sucos';
    if (RegExp(r'\b(lindoya|bioleve|crystal|[áa]gua mineral)\b')
        .hasMatch(texto))
      return 'Águas';
  }
  if (atual == 'Produtos de limpeza') {
    if (texto.contains('detergente')) return 'Detergentes';
    if (texto.contains('amaciante') || texto.contains('confort'))
      return 'Amaciantes';
    if (texto.contains('sanitária') || texto.contains('candura'))
      return 'Água sanitária';
  }
  return atual.isEmpty ? 'Outros' : atual;
}
