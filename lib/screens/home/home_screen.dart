import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/alertas/alertas_screen.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
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
            final recentes = estoque.vendasPorDia(7);
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
                        color: AppCores.roxoSuave,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        nome.isEmpty
                            ? 'M'
                            : nome.characters.first.toUpperCase(),
                        style: t.titleLarge?.copyWith(
                          color: context.cores.primary,
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7655BD), Color(0xFF4D318F)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor em estoque',
                        style: t.titleSmall?.copyWith(
                          color: AppCores.roxoSuave,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatarPreco(estoque.valorEmEstoque),
                        style: t.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${recentes.fold<int>(0, (a, b) => a + b)} un. vendidas em 7 dias',
                              style: t.bodySmall?.copyWith(
                                color: AppCores.roxoSuave,
                              ),
                            ),
                          ),
                          GraficoPainel(valores: recentes, linha: true),
                        ],
                      ),
                    ],
                  ),
                ),
                if (abrirAba != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final (indice, icone, rotulo) in const [
                          (1, Icons.inventory_2_outlined, 'Estoque'),
                          (2, Icons.qr_code_scanner, 'Operações'),
                          (3, Icons.storefront_outlined, 'Loja'),
                          (4, Icons.grid_view_outlined, 'Mais'),
                        ])
                          ActionChip(
                            avatar: Icon(icone, size: 17),
                            label: Text(rotulo),
                            onPressed: () => abrirAba!(indice),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Ações rápidas',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (i, (nome, acao)) in <(String, VoidCallback)>[
                      (
                        '+ Entrada',
                        () => mostrarMovimentarSheet(
                          context,
                          tipo: TipoMovimento.entrada,
                        ),
                      ),
                      (
                        'Inventário',
                        () => _abrir(context, const InventarioScreen()),
                      ),
                      (
                        'Pedido',
                        () => _abrir(context, const ListaComprasScreen()),
                      ),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: acao,
                          child: Text(nome, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _indicador(
                        context,
                        'Validade · ${perfil.diasAvisoValidade} dias',
                        validade,
                        Theme.of(context).brightness == Brightness.dark
                            ? AppCores.baixo
                            : const Color(0xFF8A5700),
                        FiltroEstoque.vencendo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _indicador(
                        context,
                        'Abaixo do mínimo',
                        falta,
                        AppCores.zerado,
                        FiltroEstoque.emFalta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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

  Widget _indicador(
    BuildContext context,
    String nome,
    int numero,
    Color cor,
    FiltroEstoque filtro,
  ) => CartaoPainel(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: () => _abrir(context, EstoqueScreen(filtroInicial: filtro)),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '$numero',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: cor, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );

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
