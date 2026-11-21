import 'package:flutter/material.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';

/// Números da semana e do mês, calculados a partir do histórico.
class ResumoView extends StatelessWidget {
  const ResumoView({super.key});

  static const _diasSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final saidas = estoque.saidasPorDia(7);
        final totalSemana = saidas.fold(0, (a, b) => a + b);
        final perdasQtd = estoque.perdasUnidades(30);
        final perdasValor = estoque.perdasValor(30);
        final top = estoque.maisSaidas(30);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppCores.verde,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valor em estoque', style: t.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatarPreco(estoque.valorEmEstoque),
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Soma de quantidade x preço de venda.',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Numero(
                    rotulo: 'Custo investido',
                    valor: formatarPreco(estoque.custoEmEstoque),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Numero(
                    rotulo: 'Vendas em 30 dias',
                    valor: formatarPreco(estoque.receitaVendas(30)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Numero(
              rotulo: 'Lucro estimado em 30 dias',
              valor: formatarPreco(estoque.lucroEstimado(30)),
              nota: 'Só conta produtos com preço de custo informado, usando os preços de hoje.',
            ),
            const SizedBox(height: 24),
            Text(
              'Saídas nos últimos 7 dias',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalSemana unidades no total',
              style: t.bodySmall?.copyWith(color: AppCores.cinza),
            ),
            const SizedBox(height: 16),
            _GraficoSemana(valores: saidas, rotulos: _rotulosSemana()),
            const SizedBox(height: 28),
            Text(
              'Perdas nos últimos 30 dias',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: perdasQtd > 0
                    ? AppCores.zeradoFundo
                    : AppCores.verdeSuave,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                perdasQtd == 0
                    ? 'Nenhuma perda registrada.'
                    : '$perdasQtd unidades, cerca de ${formatarPreco(perdasValor)}. '
                          'Conta as saídas com o motivo "Perda ou vencimento".',
                style: t.bodyMedium,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Mais saídas em 30 dias',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (top.isEmpty)
              Text(
                'Registre saídas para ver os produtos que mais giram.',
                style: t.bodyMedium?.copyWith(color: AppCores.cinza),
              )
            else
              for (final e in top)
                _LinhaRanking(
                  nome: e.key,
                  valor: e.value,
                  maximo: top.first.value,
                ),
          ],
        );
      },
    );
  }

  List<String> _rotulosSemana() {
    final hoje = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        _diasSemana[hoje.subtract(Duration(days: i)).weekday - 1],
    ];
  }
}

class _GraficoSemana extends StatelessWidget {
  const _GraficoSemana({required this.valores, required this.rotulos});

  final List<int> valores;
  final List<String> rotulos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final maximo = valores.fold(0, (a, b) => a > b ? a : b);
    const alturaMax = 110.0;

    return SizedBox(
      height: alturaMax + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < valores.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${valores[i]}',
                      style: t.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maximo == 0
                          ? 6
                          : (valores[i] / maximo * alturaMax)
                                .clamp(6.0, alturaMax)
                                .toDouble(),
                      decoration: BoxDecoration(
                        // Hoje em preto, os outros dias em roxo.
                        color: i == valores.length - 1
                            ? AppCores.preto
                            : AppCores.verde,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rotulos[i],
                      style: t.labelSmall?.copyWith(color: AppCores.cinza),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaRanking extends StatelessWidget {
  const _LinhaRanking({
    required this.nome,
    required this.valor,
    required this.maximo,
  });

  final String nome;
  final int valor;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fracao = maximo == 0 ? 0.0 : valor / maximo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$valor un',
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppCores.verdeSuave,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: c.maxWidth * fracao,
                  decoration: BoxDecoration(
                    color: AppCores.verde,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.rotulo, required this.valor, this.nota});

  final String rotulo;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppCores.verdeCampo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppCores.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: t.bodySmall?.copyWith(color: AppCores.cinza)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (nota != null) ...[
            const SizedBox(height: 4),
            Text(nota!, style: t.bodySmall?.copyWith(color: AppCores.cinza)),
          ],
        ],
      ),
    );
  }
}
