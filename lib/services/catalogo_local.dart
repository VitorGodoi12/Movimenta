import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/utils/codigo_produto.dart';

typedef ProdutoCatalogo = ({String nome, String categoria});

class CatalogoLocal {
  static Future<Map<String, ProdutoCatalogo>>? _catalogo;
  static const _chave = 'movimenta_catalogo_confirmado';

  static Map<String, dynamic> _confirmados() =>
      (jsonDecode(Armazenamento.ler(_chave) ?? '{}') as Map)
          .cast<String, dynamic>();

  static Future<void> recordar(String codigo, ProdutoCatalogo produto) async {
    final dados = _confirmados();
    dados[chaveCodigoProduto(codigo)] = [produto.nome, produto.categoria];
    await Armazenamento.gravar(_chave, jsonEncode(dados));
  }

  static String formatarNome(String nome, [String? medida]) {
    final unidade = RegExp(
      r'\b(\d+(?:[,.]\d+)?)\s*(kg|g|mg|ml|cl|l|un|oz|lb)\b',
      caseSensitive: false,
    );
    final embalagem =
        unidade.firstMatch(medida ?? '') ?? unidade.firstMatch(nome);
    final limpo = nome.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpo.isEmpty) return '';
    final texto = limpo[0].toUpperCase() + limpo.substring(1).toLowerCase();
    if (embalagem == null) return texto;
    final temMedidaNoNome = unidade.firstMatch(texto);
    final sufixo = embalagem[2]!.toLowerCase();
    final tamanho = embalagem[1]! + ' ' + (sufixo == 'l' ? 'L' : sufixo);
    if (temMedidaNoNome == null) return '$texto $tamanho';
    final sigla = temMedidaNoNome[2]!.toLowerCase();
    return texto.replaceRange(
      temMedidaNoNome.start,
      temMedidaNoNome.end,
      temMedidaNoNome[1]! + ' ' + (sigla == 'l' ? 'L' : sigla),
    );
  }

  static Future<ProdutoCatalogo?> buscar(String codigo) async {
    final valor = codigo.trim();
    if (!eGtin(valor)) return null;
    final confirmados = _confirmados()[chaveCodigoProduto(valor)];
    if (confirmados is List && confirmados.length == 2) {
      return (
        nome: confirmados[0] as String,
        categoria: confirmados[1] as String,
      );
    }
    final catalogo = await (_catalogo ??= _carregar());
    return catalogo[chaveCodigoProduto(valor)];
  }

  static Future<Map<String, ProdutoCatalogo>> _carregar() async {
    final itens = jsonDecode(
      await rootBundle.loadString('assets/catalogo_inicial.json'),
    ) as List;
    final planilha = jsonDecode(
      await rootBundle.loadString('assets/catalogo_produtos.json'),
    ) as Map<String, dynamic>;
    return {
      for (final linha in itens.cast<List<dynamic>>())
        chaveCodigoProduto(linha[0] as String): (
          nome: linha[1] as String,
          categoria: linha[2] as String,
        ),
      for (final item in planilha.entries)
        item.key: (
          nome: formatarNome(item.value as String),
          categoria: categoriaExibida(item.value as String, 'Outros'),
        ),
    };
  }
}
