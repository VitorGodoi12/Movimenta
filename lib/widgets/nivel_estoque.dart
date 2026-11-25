import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/selo_situacao.dart';

/// Barra de nível: o traço preto marca o estoque mínimo.
/// A escala vai de 0 até 3x o mínimo. O preenchimento anima ao mudar.
class NivelEstoque extends StatelessWidget {
  const NivelEstoque({super.key, required this.produto, this.altura = 8});

  final Produto produto;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final teto = produto.minimo * 3 < 1 ? 1 : produto.minimo * 3;
    final fracao = (produto.quantidade / teto).clamp(0.0, 1.0).toDouble();

    return SizedBox(
      height: altura,
      child: LayoutBuilder(
        builder: (context, c) {
          final largura = c.maxWidth;
          final raio = BorderRadius.circular(altura / 2);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cores.primaryContainer,
                  borderRadius: raio,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: largura * fracao,
                decoration: BoxDecoration(
                  color: produto.situacao.cor,
                  borderRadius: raio,
                ),
              ),
              Positioned(
                left: largura / 3 - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: AppCores.preto),
              ),
            ],
          );
        },
      ),
    );
  }
}
