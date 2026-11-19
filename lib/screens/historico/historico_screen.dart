import 'package:flutter/material.dart';
import 'package:movimenta/models/movimentacao.dart';
import 'package:movimenta/screens/historico/resumo_view.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/theme/app_theme.dart';
import 'package:movimenta/utils/formatadores.dart';
import 'package:movimenta/widgets/estado_vazio.dart';
import 'package:movimenta/widgets/movimentacao_tile.dart';

class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Histórico'),
          bottom: const TabBar(
            labelColor: AppCores.preto,
            unselectedLabelColor: AppCores.cinza,
            indicatorColor: AppCores.roxo,
            indicatorWeight: 3,
            dividerColor: AppCores.linha,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Movimentações'),
              Tab(text: 'Resumo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListaMovimentacoes(),
            ResumoView(),
          ],
        ),
      ),
    );
  }
}

class _ListaMovimentacoes extends StatelessWidget {
  const _ListaMovimentacoes();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final lista = estoque.historico;
        if (lista.isEmpty) {
          return const EstadoVazio(
            icone: Icons.history,
            titulo: 'Nada registrado ainda',
            texto: 'Entradas, saídas, ajustes e cadastros aparecem aqui.',
          );
        }

        // Mistura títulos de dia (String) e movimentações.
        final itens = <Object>[];
        String? diaAtual;
        for (final m in lista) {
          final dia = rotuloDia(m.data);
          if (dia != diaAtual) {
            itens.add(dia);
            diaAtual = dia;
          }
          itens.add(m);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: itens.length,
          itemBuilder: (context, i) {
            final item = itens[i];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 2),
                child: Text(
                  item,
                  style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppCores.cinza,
                  ),
                ),
              );
            }
            return MovimentacaoTile(mov: item as Movimentacao);
          },
        );
      },
    );
  }
}
