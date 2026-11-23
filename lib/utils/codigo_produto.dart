final _gtin = RegExp(r'^(?:\d{8}|\d{12,14})$');
final _interno = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

bool eGtin(String codigo) => _gtin.hasMatch(codigo);

/// Extrai GTINs explícitos sem abrir ou seguir o link lido.
String? codigoDeProduto(String? leitura) {
  final valor = leitura?.trim() ?? '';
  if (_interno.hasMatch(valor)) return valor;
  final uri = Uri.tryParse(valor);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  try {
    final segmentos = uri.pathSegments;
    for (var i = 0; i + 1 < segmentos.length; i++) {
      final candidato = segmentos[i + 1];
      if (segmentos[i] == '01' && candidato.length == 14 && eGtin(candidato)) {
        return candidato;
      }
    }
    for (final chave in ['gtin', 'ean', 'upc', 'barcode']) {
      final candidato = uri.queryParameters[chave];
      if (candidato != null && eGtin(candidato)) return candidato;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Compara a mesma identificação em EAN/UPC ou preenchida para GS1.
String chaveCodigoProduto(String codigo) =>
    eGtin(codigo) ? codigo.padLeft(14, '0') : codigo;
