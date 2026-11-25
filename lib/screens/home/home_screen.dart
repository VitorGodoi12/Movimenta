import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/fluxo_scanner.dart';
import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/alertas/alertas_screen.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/screens/inventario/inventario_screen.dart';
import 'package:stokio/screens/historico/historico_screen.dart';
import 'package:stokio/widgets/movimentacao_tile.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/cartao_painel.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.abrirAba});
  final ValueChanged<int>? abrirAba;

  void _abrir(BuildContext context, Widget tela) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => tela));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([estoque, perfil]),
          builder: (context, _) {
            final nome =
                perfil.cliente?.nome.trim().split(RegExp(r'\s+')).first ?? '';
            final falta = estoque.baixos.length + estoque.zerados.length;
            final validade = estoque.vencidos.length + estoque.vencendo.length;
            final movimentosHoje = estoque.historico
                .where((m) => DateUtils.isSameDay(m.data, DateTime.now()))
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.cores.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        nome.isEmpty
                            ? 'M'
                            : nome.characters.first.toUpperCase(),
                        style: t.titleLarge?.copyWith(
                          color: context.cores.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descricaoHoje(),
                            style: t.bodySmall?.copyWith(
                              color: context.cores.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            nome.isEmpty ? 'Olá!' : 'Olá, $nome',
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Alertas do estoque',
                      onPressed: () => _abrir(context, const AlertasScreen()),
                      icon: Badge(
                        isLabelVisible: estoque.alertas.isNotEmpty,
                        label: Text('${estoque.alertas.length}'),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, limites) {
                    final largura =
                        limites.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 20
                        ? limites.maxWidth
                        : (limites.maxWidth - 12) / 2;
                    final dados =
                        <(IconData, String, String, String, VoidCallback)>[
                          (
                            Icons.inventory_2_outlined,
                            'Produtos',
                            estoque.total.toString(),
                            'Cadastros ativos',
                            () => abrirAba?.call(1),
                          ),
                          (
                            Icons.account_balance_wallet_outlined,
                            'Valor em estoque',
                            formatarPreco(estoque.valorEmEstoque),
                            'Custo: ' + formatarPreco(estoque.custoEmEstoque),
                            () => _abrir(context, const HistoricoScreen()),
                          ),
                          (
                            Icons.warning_amber_rounded,
                            'Abaixo do mínimo',
                            falta.toString(),
                            'Validades próximas: ' + validade.toString(),
                            () => _abrir(context, const AlertasScreen()),
                          ),
                          (
                            Icons.swap_horiz_rounded,
                            'Movimentos de hoje',
                            movimentosHoje.toString(),
                            'Entradas, saídas e ajustes',
                            () => _abrir(context, const HistoricoScreen()),
                          ),
                        ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final (icone, rotulo, numero, nota, acao) in dados)
                          SizedBox(
                            width: largura,
                            child: CartaoPainel(
                              padding: EdgeInsets.zero,
                              child: InkWell(
                                onTap: acao,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        icone,
                                        size: 20,
                                        color: context.cores.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(rotulo, style: t.labelLarge),
                                      const SizedBox(height: 3),
                                      Text(
                                        numero,
                                        style: t.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        nota,
                                        style: t.bodySmall?.copyWith(
                                          color: context.cores.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Ações rápidas',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (icone, rotulo, acao)
                        in <(IconData, String, VoidCallback)>[
                          (
                            Icons.south_west_rounded,
                            'Entrada',
                            () => mostrarMovimentarSheet(context),
                          ),
                          (
                            Icons.north_east_rounded,
                            'Saída',
                            () => mostrarMovimentarSheet(
                              context,
                              tipo: TipoMovimento.saida,
                            ),
                          ),
                          (
                            Icons.add_box_outlined,
                            'Cadastrar',
                            () => _abrir(context, const ProdutoFormScreen()),
                          ),
                          (
                            Icons.qr_code_scanner,
                            'Ler código',
                            () => escanearEAbrir(context),
                          ),
                          (
                            Icons.fact_check_outlined,
                            'Inventário',
                            () => _abrir(context, const InventarioScreen()),
                          ),
                          (
                            Icons.shopping_cart_outlined,
                            'Pedido',
                            () => _abrir(context, const ListaComprasScreen()),
                          ),
                        ])
                      ActionChip(
                        avatar: Icon(icone, size: 18),
                        label: Text(rotulo),
                        onPressed: acao,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                CartaoPainel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precisa de atenção',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (estoque.alertas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Nenhum alerta agora.'),
                        ),
                      for (final produto in estoque.alertas.take(4))
                        _alerta(context, produto),
                    ],
                  ),
                ),
                if (estoque.historico.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CartaoPainel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Movimentações recentes',
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _abrir(context, const HistoricoScreen()),
                              child: const Text('Ver histórico'),
                            ),
                          ],
                        ),
                        for (final movimento in estoque.historico.take(3))
                          MovimentacaoTile(mov: movimento),
                      ],
                    ),
                  ),
                ],
                if (estoque.maisVendidos().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CartaoPainel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saída rápida',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        for (final produto in estoque.maisVendidos())
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(produto.nome),
                            subtitle: Text(
                              '${produto.quantidade} ${produto.unidade} em estoque',
                            ),
                            trailing: IconButton.outlined(
                              tooltip: 'Vender uma unidade de ${produto.nome}',
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                final mov = estoque.movimentar(
                                  produto,
                                  TipoMovimento.saida,
                                  1,
                                  motivo: Motivos.venda,
                                );
                                if (mov != null)
                                  avisarComDesfazer(
                                    context,
                                    'Unidade vendida.',
                                    [mov],
                                  );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _alerta(BuildContext context, Produto produto) {
    final vencimento = produto.validade;
    final minimo = produto.minimo;
    return InkWell(
      onTap: () => _abrir(context, ProdutoDetalheScreen(produto: produto)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    produto.nome,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  minimo > 0
                      ? '${produto.quantidade} de $minimo'
                      : '${produto.quantidade} ${produto.unidade}',
                ),
              ],
            ),
            if (minimo > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  value: (produto.quantidade / minimo).clamp(0.0, 1.0),
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: context.cores.surfaceContainerHighest,
                  color: produto.quantidade == 0
                      ? AppCores.zerado
                      : AppCores.baixo,
                ),
              ),
            if (vencimento != null)
              Text(
                'Validade ${formatarData(vencimento)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
