import 'dart:convert';
import 'dart:io';

import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/utils/codigo_produto.dart';

class OpenFoodFacts {
  static const disponivel = true;
  static const _limite = Duration(seconds: 5);

  static Future<({String nome, String categoria, String? marca, String fonte})?>
  buscar(String codigo) async {
    if (!eGtin(codigo)) return null;
    if (codigo.length == 14 && codigo.startsWith('0')) {
      codigo = codigo.substring(1);
    }
    Exception? falha;
    const catalogos = [
      ('world.openfoodfacts.org', 'Open Food Facts'),
      ('world.openbeautyfacts.org', 'Open Beauty Facts'),
    ];
    for (final (host, fonte) in catalogos) {
      try {
        final produto = await _buscarNoCatalogo(codigo, host, fonte);
        if (produto != null) return produto;
      } on Exception catch (erro) {
        falha = erro;
      }
    }
    if (falha != null) throw falha;
    return null;
  }

  static Future<({String nome, String categoria, String? marca, String fonte})?>
  _buscarNoCatalogo(String codigo, String host, String fonte) async {
    final url = Uri.https(host, '/api/v2/product/$codigo', {
      'fields': 'product_name_pt,product_name,brands,categories_tags',
    });
    final cliente = HttpClient()..connectionTimeout = _limite;
    try {
      return await _ler(cliente, url, fonte).timeout(_limite);
    } finally {
      cliente.close(force: true);
    }
  }

  static Future<({String nome, String categoria, String? marca, String fonte})?>
  _ler(HttpClient cliente, Uri url, String fonte) async {
    final pedido = await cliente.getUrl(url);
    pedido.headers.set(
      HttpHeaders.userAgentHeader,
      'Stokio/1.7.1 (https://github.com/VitorGodoi12/Stokio)',
    );
    final resposta = await pedido.close();
    if (resposta.statusCode == HttpStatus.notFound) return null;
    if (resposta.statusCode != HttpStatus.ok) {
      throw HttpException('Catálogo indisponível', uri: url);
    }
    final dados = jsonDecode(await resposta.transform(utf8.decoder).join());
    if (dados is! Map || dados['product'] is! Map) return null;
    final produto = dados['product'] as Map;
    final nome =
        _texto(produto['product_name_pt']) ?? _texto(produto['product_name']);
    if (nome == null) return null;
    final tags = produto['categories_tags'];
    final categorias = tags is List
        ? tags.whereType<String>().toSet()
        : <String>{};
    const correspondencias = {
      'en:sodas': 'Refrigerantes',
      'en:energy-drinks': 'Energéticos',
      'en:fruit-juices': 'Sucos',
      'en:waters': 'Águas',
      'en:beers': 'Cervejas',
      'en:milks': 'Leites',
      'en:dairies': 'Laticínios',
      'en:rices': 'Arroz',
      'en:pastas': 'Massas',
      'en:coffees': 'Cafés',
      'en:biscuits': 'Biscoitos',
      'en:chocolates': 'Chocolates',
      'en:breads': 'Mercearia',
      'en:frozen-foods': 'Salgados e congelados',
    };
    final tag = correspondencias.keys.where(categorias.contains).firstOrNull;
    return (
      nome: nome,
      marca: _texto(produto['brands']),
      categoria:
          correspondencias[tag] ??
          categoriaExibida(
            nome,
            fonte == 'Open Beauty Facts' ? 'Higiene' : 'Outros',
          ),
      fonte: fonte,
    );
  }

  static String? _texto(Object? valor) =>
      valor is String && valor.trim().isNotEmpty ? valor.trim() : null;
}
