import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stokio/models/cliente.dart';
import 'package:stokio/services/armazenamento.dart';

final PerfilService perfil = PerfilService();

/// Dados do estabelecimento e preferências do app.
class PerfilService extends ChangeNotifier {
  static const _chave = 'movimenta_perfil_v1';

  static const _chaveBackup = 'stokio_ultimo_backup';
  DateTime? ultimoBackup;

  bool get backupPendente =>
      ultimoBackup == null ||
      DateTime.now().difference(ultimoBackup!).inDays >= 7;

  Future<void> registrarBackup() async {
    final agora = DateTime.now();
    if (!await Armazenamento.gravar(_chaveBackup, agora.toIso8601String())) {
      throw StateError('Não foi possível registrar a data do backup.');
    }
    ultimoBackup = agora;
    notifyListeners();
  }

  Cliente? cliente;
  int diasAvisoValidade = 7;

  Future<void> carregar() async {
    ultimoBackup = DateTime.tryParse(Armazenamento.ler(_chaveBackup) ?? '');
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
