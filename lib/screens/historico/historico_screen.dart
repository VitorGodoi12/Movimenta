import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/screens/historico/resumo_view.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/exportacao_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/estado_vazio.dart';
import 'package:stokio/widgets/movimentacao_tile.dart';

class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Histórico'),
          actions: [
            IconButton(
              tooltip: 'Exportar histórico (CSV)',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => ExportacaoService.compartilhar(
                'historico-movimenta.csv',
                ExportacaoService.csvHistorico(),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppCores.preto,
            unselectedLabelColor: AppCores.cinza,
            indicatorColor: AppCores.verde,
            indicatorWeight: 3,
            dividerColor: AppCores.linha,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Movimentações'),
              Tab(text: 'Resumo'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ListaMovimentacoes(), ResumoView()]),
      ),
    );
  }
}

enum _FiltroMov { todas, entradas, saidas, ajustes }

class _ListaMovimentacoes extends StatefulWidget {
  const _ListaMovimentacoes();

  @override
  State<_ListaMovimentacoes> createState() => _ListaMovimentacoesState();
}

class _ListaMovimentacoesState extends State<_ListaMovimentacoes> {
  _FiltroMov _filtro = _FiltroMov.todas;

  String _rotulo(_FiltroMov f) => switch (f) {
    _FiltroMov.todas => 'Todas',
    _FiltroMov.entradas => 'Entradas',
    _FiltroMov.saidas => 'Saídas',
    _FiltroMov.ajustes => 'Ajustes',
  };

  bool _passa(Movimentacao m) => switch (_filtro) {
    _FiltroMov.todas => true,
    _FiltroMov.entradas =>
      m.tipo == TipoMovimento.entrada || m.tipo == TipoMovimento.cadastro,
    _FiltroMov.saidas => m.tipo == TipoMovimento.saida,
    _FiltroMov.ajustes => m.tipo == TipoMovimento.ajuste,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final todas = estoque.historico;
        final lista = todas.where(_passa).toList();

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

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                children: [
                  for (final f in _FiltroMov.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_rotulo(f)),
                        selected: _filtro == f,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: todas.isEmpty
                  ? const EstadoVazio(
                      icone: Icons.history,
                      titulo: 'Nada registrado ainda',
                      texto: 'Entradas, saídas, ajustes e cadastros aparecem aqui.',
                    )
                  : lista.isEmpty
                  ? const EstadoVazio(
                      icone: Icons.filter_alt_off_outlined,
                      titulo: 'Nada neste filtro',
                      texto: 'Escolha outro tipo de movimentação.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                    ),
            ),
          ],
        );
      },
    );
  }
}
