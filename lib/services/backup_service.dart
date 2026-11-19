import 'dart:convert';

import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';

/// Backup em texto (JSON). Como os dados ficam só no aparelho,
/// o backup é a forma de levar tudo para outro celular.
class BackupService {
  BackupService._();

  static String exportar() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'movimenta',
      'versao': 1,
      'perfil': perfil.toJson(),
      'estoque': estoque.toJson(),
    });
  }

  /// Lança exceção se o texto não for um backup válido.
  static Future<void> importar(String texto) async {
    final j = jsonDecode(texto.trim());
    if (j is! Map<String, dynamic> || j['app'] != 'movimenta') {
      throw const FormatException('Não é um backup do Movimenta.');
    }
    estoque.aplicarJson(j['estoque'] as Map<String, dynamic>);
    perfil.aplicarJson(j['perfil'] as Map<String, dynamic>);
    await estoque.salvar();
    await perfil.salvar();
  }
}
