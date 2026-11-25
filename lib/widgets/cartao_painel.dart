import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stokio/theme/app_theme.dart';

class CartaoPainel extends StatelessWidget {
  const CartaoPainel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: context.cores.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.cores.outlineVariant),
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class GraficoPainel extends StatelessWidget {
  const GraficoPainel({super.key, required this.valores, this.linha = false});
  final List<num> valores;
  final bool linha;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<num>(0, math.max);
    if (linha) {
      return SizedBox(
        height: 38,
        width: 100,
        child: CustomPaint(painter: _Linha(valores, maximo)),
      );
    }
    return SizedBox(
      height: 54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, valor) in valores.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: maximo == 0
                      ? 3
                      : math.max(3, 54 * valor / maximo).toDouble(),
                  decoration: BoxDecoration(
                    color: i == valores.length - 1
                        ? AppCores.roxoAcao
                        : context.cores.primaryContainer,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Linha extends CustomPainter {
  const _Linha(this.valores, this.maximo);
  final List<num> valores;
  final num maximo;

  @override
  void paint(Canvas canvas, Size size) {
    if (maximo <= 0 || valores.length < 2) return;
    final caminho = Path();
    for (final (i, valor) in valores.indexed) {
      final x = 2 + (size.width - 4) * i / (valores.length - 1);
      final y = size.height - 3 - (size.height - 6) * valor / maximo;
      if (i == 0) {
        caminho.moveTo(x, y);
      } else {
        caminho.lineTo(x, y);
      }
    }
    canvas.drawPath(
      caminho,
      Paint()
        ..color = const Color(0xFFE0D1FF)
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Linha oldDelegate) => oldDelegate.valores != valores;
}
