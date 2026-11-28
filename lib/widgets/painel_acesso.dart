import 'package:flutter/material.dart';
import 'package:stokio/widgets/marca_stokio.dart';

class PainelAcesso extends StatelessWidget {
  const PainelAcesso({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.child,
  });

  final String titulo;
  final String descricao;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: tema.scaffoldBackgroundColor),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8E3B91),
                    Color(0xFF6543AC),
                    Color(0xFF453486),
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.paddingOf(context).top + 245,
                child: const CustomPaint(painter: _ArcosAcesso()),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: DefaultTextStyle(
                            style: TextStyle(color: Colors.white),
                            child: MarcaStokio(altura: 42),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          titulo,
                          style: tema.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          descricao,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFF5E9FF),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Material(
                          color: tema.colorScheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          elevation: 2,
                          shadowColor: const Color(0x40342153),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcosAcesso extends CustomPainter {
  const _ArcosAcesso();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = const Color(0x25FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final centro = Offset(size.width * .93, -30);
    for (final raio in [56.0, 80.0, 104.0, 128.0, 152.0]) {
      canvas.drawCircle(centro, raio, pincel);
    }
  }

  @override
  bool shouldRepaint(_ArcosAcesso anterior) => false;
}
