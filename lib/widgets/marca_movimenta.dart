import 'package:flutter/material.dart';
import 'package:movimenta/theme/app_theme.dart';

/// Três barras de alturas diferentes: lembram níveis de estoque.
class MarcaMovimenta extends StatelessWidget {
  const MarcaMovimenta({
    super.key,
    this.altura = 28,
    this.mostrarNome = true,
    this.corDestaque = AppCores.branco,
  });

  final double altura;
  final bool mostrarNome;
  final Color corDestaque;

  @override
  Widget build(BuildContext context) {
    final largura = altura * 0.22;

    Widget barra(double fator, Color cor) => Container(
          width: largura,
          height: altura * fator,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(largura / 2),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            barra(0.45, AppCores.preto),
            SizedBox(width: largura * 0.6),
            barra(0.72, AppCores.preto),
            SizedBox(width: largura * 0.6),
            barra(1, corDestaque),
          ],
        ),
        if (mostrarNome) ...[
          SizedBox(width: altura * 0.4),
          Text(
            'movimenta',
            style: TextStyle(
              fontSize: altura * 0.85,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppCores.preto,
            ),
          ),
        ],
      ],
    );
  }
}
