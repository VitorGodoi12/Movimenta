import 'dart:convert';

import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';

/// Backup em texto (JSON). Como os dados ficam só no aparelho,
/// o backup é a forma de levar tudo para outro celular.
class BackupService {
  BackupService._();

  static String exportar() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'stokio',
      'versao': 1,
      'perfil': perfil.toJson(),
      'estoque': estoque.toJson(),
    });
  }

  static Map<String, dynamic> _ler(String texto) {
    final j = jsonDecode(texto.trim());
    if (j is! Map<String, dynamic> ||
        !const ['stokio', 'movimenta'].contains(j['app'])) {
      throw const FormatException('Não é um backup do Stokio.');
    }
    return j;
  }

  static ({int produtos, int movimentos, int fornecedores}) testar(
    String texto,
  ) {
    final dados = _ler(texto);
    final inventario = EstoqueService();
    final cadastro = PerfilService();
    try {
      inventario.aplicarJson(dados['estoque'] as Map<String, dynamic>);
      cadastro.aplicarJson(dados['perfil'] as Map<String, dynamic>);
      return (
        produtos: inventario.produtos.length,
        movimentos: inventario.historico.length,
        fornecedores: inventario.fornecedores.length,
      );
    } finally {
      inventario.dispose();
      cadastro.dispose();
    }
  }

  static Future<void> importar(String texto) async {
    testar(texto);
    final dados = _ler(texto);
    estoque.aplicarJson(dados['estoque'] as Map<String, dynamic>);
    perfil.aplicarJson(dados['perfil'] as Map<String, dynamic>);
    await estoque.salvar();
    await perfil.salvar();
  }
}
