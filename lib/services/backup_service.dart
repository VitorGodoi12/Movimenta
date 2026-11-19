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

  /// Lança exceção se o texto não for um backup válido.
  static Future<void> importar(String texto) async {
    final j = jsonDecode(texto.trim());
    if (j is! Map<String, dynamic> || !const ['stokio', 'movimenta'].contains(j['app'])) {
      throw const FormatException('Não é um backup do Stokio.');
    }
    estoque.aplicarJson(j['estoque'] as Map<String, dynamic>);
    perfil.aplicarJson(j['perfil'] as Map<String, dynamic>);
    await estoque.salvar();
    await perfil.salvar();
  }
}
