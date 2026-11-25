import 'package:flutter/material.dart';

class MarcaStokio extends StatelessWidget {
  const MarcaStokio({super.key, this.altura = 34, this.mostrarNome = true});

  final double altura;
  final bool mostrarNome;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(altura * 0.24),
          child: Image.asset(
            'assets/images/stokio.png',
            width: altura,
            height: altura,
            excludeFromSemantics: mostrarNome,
            semanticLabel: 'Movimenta',
          ),
        ),
        if (mostrarNome) ...[
          SizedBox(width: altura * 0.28),
          Text(
            'Movimenta',
            style: TextStyle(
              fontSize: altura * 0.8,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
