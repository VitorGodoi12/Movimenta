import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';

class Notificacoes {
  static const _canal = MethodChannel('stokio/alertas');
  static bool get disponivel =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void iniciar() {
    if (!disponivel) return;
    estoque.addListener(_atualizar);
    perfil.addListener(_atualizar);
    _atualizar();
  }

  static void _atualizar() => unawaited(sincronizar());

  static Future<void> sincronizar() async {
    if (!disponivel) return;
    try {
      await _canal.invokeMethod<void>('sincronizar', {
        'baixo': estoque.baixos.length + estoque.zerados.length,
        'dias': perfil.diasAvisoValidade,
        'datas': [
          for (final produto in estoque.produtos)
            for (final data in produto.lotes.keys.whereType<DateTime>())
              data.toIso8601String().split('T').first,
        ],
      });
    } on PlatformException catch (erro) {
      debugPrint('Falha ao sincronizar notificações: ${erro.code}');
    } on MissingPluginException {
      // O canal só é instalado no aplicativo Android.
    }
  }

  static Future<bool> permitido() async =>
      disponivel && (await _canal.invokeMethod<bool>('permitido') ?? false);

  static Future<bool> ativar() async {
    final ativo =
        disponivel && (await _canal.invokeMethod<bool>('ativar') ?? false);
    if (ativo) await sincronizar();
    return ativo;
  }

  static Future<bool> testar() async =>
      disponivel && (await _canal.invokeMethod<bool>('testar') ?? false);

  static Future<void> abrirConfiguracoes() =>
      _canal.invokeMethod<void>('configuracoes');
}
