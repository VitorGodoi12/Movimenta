import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stokio/models/cliente.dart';

const coresAvatar = [
  ('Roxo', Color(0xFF6444A2)),
  ('Azul', Color(0xFF275E98)),
  ('Verde', Color(0xFF256454)),
  ('Vinho', Color(0xFF8A405F)),
];

class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({super.key, required this.cliente, this.tamanho = 48});

  final Cliente? cliente;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final nome = cliente?.nomeExibicao.trim() ?? '';
    final cor = (cliente?.corAvatar ?? 0).clamp(0, coresAvatar.length - 1);
    final foto = cliente?.foto;

    Widget inicial() => Center(
      child: Text(
        nome.isEmpty ? 'M' : nome.characters.first.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: tamanho * .43,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget imagem() {
      if (foto == null || foto.isEmpty || foto.length > 400000)
        return inicial();
      try {
        return Image.memory(
          base64Decode(foto),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => inicial(),
        );
      } on FormatException {
        return inicial();
      }
    }

    return SizedBox.square(
      dimension: tamanho,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tamanho * .31),
        child: ColoredBox(color: coresAvatar[cor].$2, child: imagem()),
      ),
    );
  }
}
