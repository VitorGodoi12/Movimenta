import 'package:flutter/material.dart';
import 'package:stokio/services/armazenamento.dart';

class TemaPreferencia {
  static const _chave = 'movimenta_aparencia';
  static final modo = ValueNotifier(ThemeMode.system);

  static void carregar() {
    final salvo = Armazenamento.ler(_chave);
    modo.value = ThemeMode.values.firstWhere(
      (tema) => tema.name == salvo,
      orElse: () => ThemeMode.system,
    );
  }

  static void definir(ThemeMode novo) {
    modo.value = novo;
    Armazenamento.gravar(_chave, novo.name);
  }
}
