import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:stokio/utils/codigo_produto.dart';

typedef ProdutoCatalogo = ({String nome, String categoria});

class CatalogoLocal {
  static Future<Map<String, ProdutoCatalogo>>? _catalogo;

  static Future<ProdutoCatalogo?> buscar(String codigo) async {
    final valor = codigo.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(valor)) return null;
    final catalogo = await (_catalogo ??= _carregar());
    return catalogo[chaveCodigoProduto(valor)];
  }

  static Future<Map<String, ProdutoCatalogo>> _carregar() async {
    final itens = jsonDecode(
      await rootBundle.loadString('assets/catalogo_inicial.json'),
    ) as List;
    return {
      for (final linha in itens.cast<List<dynamic>>())
        chaveCodigoProduto(linha[0] as String): (
          nome: linha[1] as String,
          categoria: linha[2] as String,
        ),
    };
  }
}
