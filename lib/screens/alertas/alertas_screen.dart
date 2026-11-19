import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/widgets/estado_vazio.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';
import 'package:stokio/widgets/produto_tile.dart';

class AlertasScreen extends StatelessWidget {
  const AlertasScreen({super.key});

  Widget _tile(
    BuildContext context,
    Produto p, {
    required String rotuloAcao,
    required IconData icone,
    required TipoMovimento tipo,
    String? motivo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProdutoTile(
        produto: p,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProdutoDetalheScreen(produto: p)),
        ),
        acao: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => mostrarMovimentarSheet(
              context,
              produto: p,
              tipo: tipo,
              motivo: motivo,
            ),
            icon: Icon(icone, size: 18),
            label: Text(rotuloAcao),
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context, String texto, {double topo = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: topo, bottom: 12),
      child: Text(
        texto,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([estoque, perfil]),
      builder: (context, _) {
        final g = estoque.grupos;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Alertas'),
            actions: [
              IconButton(
                tooltip: 'Lista de compras',
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ListaComprasScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: g.total == 0
              ? const EstadoVazio(
                  icone: Icons.check_circle_outline,
                  titulo: 'Nenhum alerta',
                  texto:
                      'Nada vencido, vencendo, zerado ou abaixo do estoque mínimo.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (g.vencidos.isNotEmpty) ...[
                      _cabecalho(context, 'Vencidos (${g.vencidos.length})'),
                      for (final p in g.vencidos)
                        _tile(
                          context,
                          p,
                          rotuloAcao: 'Registrar perda',
                          icone: Icons.remove,
                          tipo: TipoMovimento.saida,
                          motivo: Motivos.perda,
                        ),
                    ],
                    if (g.vencendo.isNotEmpty) ...[
                      _cabecalho(context, 'Vencendo (${g.vencendo.length})',
                          topo: g.vencidos.isEmpty ? 0 : 8),
                      for (final p in g.vencendo)
                        _tile(
                          context,
                          p,
                          rotuloAcao: 'Registrar saída',
                          icone: Icons.remove,
                          tipo: TipoMovimento.saida,
                        ),
                    ],
                    if (g.zerados.isNotEmpty) ...[
                      _cabecalho(context, 'Zerados (${g.zerados.length})',
                          topo: (g.vencidos.isEmpty && g.vencendo.isEmpty)
                              ? 0
                              : 8),
                      for (final p in g.zerados)
                        _tile(
                          context,
                          p,
                          rotuloAcao: 'Registrar entrada',
                          icone: Icons.add,
                          tipo: TipoMovimento.entrada,
                        ),
                    ],
                    if (g.baixos.isNotEmpty) ...[
                      _cabecalho(context, 'Acabando (${g.baixos.length})',
                          topo: (g.vencidos.isEmpty &&
                                  g.vencendo.isEmpty &&
                                  g.zerados.isEmpty)
                              ? 0
                              : 8),
                      for (final p in g.baixos)
                        _tile(
                          context,
                          p,
                          rotuloAcao: 'Registrar entrada',
                          icone: Icons.add,
                          tipo: TipoMovimento.entrada,
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
