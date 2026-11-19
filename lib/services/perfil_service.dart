import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movimenta/models/cliente.dart';
import 'package:movimenta/services/armazenamento.dart';

final PerfilService perfil = PerfilService();

/// Dados do estabelecimento e preferências do app.
class PerfilService extends ChangeNotifier {
  static const _chave = 'movimenta_perfil_v1';

  Cliente? cliente;
  int diasAvisoValidade = 7;

  Future<void> carregar() async {
    final texto = Armazenamento.ler(_chave);
    if (texto == null) return;
    try {
      aplicarJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      // Dados corrompidos: começa do zero.
    }
  }

  Map<String, dynamic> toJson() => {
        'cliente': cliente?.toJson(),
        'diasAvisoValidade': diasAvisoValidade,
      };

  void aplicarJson(Map<String, dynamic> j) {
    final c = j['cliente'];
    cliente = c == null ? null : Cliente.fromJson(c as Map<String, dynamic>);
    diasAvisoValidade = (j['diasAvisoValidade'] as num?)?.toInt() ?? 7;
    notifyListeners();
  }

  Future<void> salvar() => Armazenamento.gravar(_chave, jsonEncode(toJson()));

  Future<void> definirCliente(Cliente novo) async {
    cliente = novo;
    notifyListeners();
    await salvar();
  }

  Future<void> definirDiasAviso(int dias) async {
    diasAvisoValidade = dias;
    notifyListeners();
    await salvar();
  }
}
