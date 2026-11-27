import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/mercado_firebase.dart';

class FilaEntradasMercado {
  FilaEntradasMercado(this.uid, this.mercadoId);

  final String uid;
  final String mercadoId;
  String get _chave => 'movimenta_entradas_pendentes_' + uid + '_' + mercadoId;
  bool _sincronizando = false;

  List<Map<String, dynamic>> get _entradas =>
      (jsonDecode(Armazenamento.ler(_chave) ?? '[]') as List)
          .cast<Map<String, dynamic>>();

  int get pendentes => _entradas.length;

  Future<bool> enviar(Map<String, dynamic> entrada) async {
    if (MercadoFirebase.auth.currentUser?.uid != uid)
      throw StateError('Sessão mudou.');
    try {
      await MercadoFirebase.chamar(
        'confirmarEntrada',
        entrada,
      ).timeout(const Duration(seconds: 12));
      return true;
    } on FirebaseFunctionsException catch (erro) {
      if (!const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      }.contains(erro.code))
        rethrow;
    } on TimeoutException {
      // O identificador da entrada permite reenviar sem duplicar.
    }
    final fila =
        _entradas
            .where((item) => item['entradaId'] != entrada['entradaId'])
            .toList()
          ..add(entrada);
    if (!await Armazenamento.gravar(_chave, jsonEncode(fila))) {
      throw StateError('Falha ao salvar a entrada no aparelho.');
    }
    return false;
  }

  Future<void> sincronizar() async {
    if (_sincronizando || MercadoFirebase.auth.currentUser?.uid != uid) return;
    _sincronizando = true;
    try {
      for (final entrada in _entradas) {
        if (MercadoFirebase.auth.currentUser?.uid != uid) return;
        await MercadoFirebase.chamar(
          'confirmarEntrada',
          entrada,
        ).timeout(const Duration(seconds: 12));
        final atual = _entradas
            .where((item) => item['entradaId'] != entrada['entradaId'])
            .toList();
        if (!await Armazenamento.gravar(_chave, jsonEncode(atual)))
          throw StateError('Falha ao atualizar a fila.');
      }
    } finally {
      _sincronizando = false;
    }
  }
}
