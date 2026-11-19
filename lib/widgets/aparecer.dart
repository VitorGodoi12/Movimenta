import 'package:flutter/material.dart';

/// Faz o conteúdo surgir suavemente (fade + leve subida).
/// [indice] escalona a entrada de itens em sequência.
class Aparecer extends StatelessWidget {
  const Aparecer({super.key, required this.child, this.indice = 0});

  final Widget child;
  final int indice;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + indice * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, filho) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: filho,
        ),
      ),
      child: child,
    );
  }
}
