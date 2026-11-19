import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/configuracoes/configuracoes_screen.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/fornecedores/fornecedores_screen.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/inventario/inventario_screen.dart';
import 'package:stokio/screens/scanner/fluxo_scanner.dart';
import 'package:stokio/screens/venda/venda_rapida_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/aparecer.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/movimentacao_tile.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';
import 'package:stokio/widgets/produto_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.irPara});

  /// Troca a aba da barra inferior (1 = Estoque, 2 = Alertas, 3 = Histórico).
  final ValueChanged<int> irPara;

  void _abrir(BuildContext context, Widget tela) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
  }

  void _venderUm(BuildContext context, Produto p) {
    final mov = estoque.movimentar(p, TipoMovimento.saida, 1,
        motivo: Motivos.venda);
    if (mov != null) {
      avisarComDesfazer(
          context, 'Vendido: 1 ${p.unidade} de ${p.nome}.', [mov]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: Listenable.merge([estoque, perfil]),
      builder: (context, _) {
        final cliente = perfil.cliente;
        final alertas = estoque.alertas.take(3).toList();
        final recentes = estoque.historico.take(4).toList();
        final rapidos = estoque.maisVendidos();
        final vencimentos = estoque.vencidos.length + estoque.vencendo.length;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descricaoHoje(),
                  style: t.bodySmall?.copyWith(
                    color: AppCores.cinza,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('Olá, ${cliente?.primeiroNome ?? ''}'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _abrir(context, const ConfiguracoesScreen()),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Aparecer(
                child: _Hero(
                  estabelecimento: cliente?.estabelecimento ?? 'Meu estoque',
                  total: estoque.total,
                  baixos: estoque.baixos.length,
                  zerados: estoque.zerados.length,
                  vencimentos: vencimentos,
                  irPara: irPara,
                ),
              ),
              const SizedBox(height: 16),
              Aparecer(
                indice: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: _AcaoRapida(
                        icone: Icons.add,
                        rotulo: 'Entrada',
                        aoTocar: () => mostrarMovimentarSheet(context,
                            tipo: TipoMovimento.entrada),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AcaoRapida(
                        icone: Icons.remove,
                        rotulo: 'Saída',
                        aoTocar: () => mostrarMovimentarSheet(context,
                            tipo: TipoMovimento.saida),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AcaoRapida(
                        icone: Icons.qr_code_scanner,
                        rotulo: 'Escanear',
                        aoTocar: () => escanearEAbrir(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AcaoRapida(
                        icone: Icons.point_of_sale,
                        rotulo: 'Vender',
                        destaque: true,
                        aoTocar: () =>
                            _abrir(context, const VendaRapidaScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Aparecer(
                indice: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Inventário'),
                      onPressed: () =>
                          _abrir(context, const InventarioScreen()),
                    ),
                    ActionChip(
                      avatar:
                          const Icon(Icons.shopping_cart_outlined, size: 18),
                      label: const Text('Lista de compras'),
                      onPressed: () =>
                          _abrir(context, const ListaComprasScreen()),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.local_shipping_outlined,
                          size: 18),
                      label: const Text('Fornecedores'),
                      onPressed: () =>
                          _abrir(context, const FornecedoresScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (estoque.total == 0)
                const _PrimeirosPassos()
              else ...[
                if (rapidos.isNotEmpty) ...[
                  Aparecer(
                    indice: 3,
                    child: _Secao(titulo: 'Saída rápida', subtitulo: 'Toque para vender 1 unidade'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rapidos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => _CartaoSaidaRapida(
                        produto: rapidos[i],
                        aoVender: () => _venderUm(context, rapidos[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                Aparecer(
                  indice: 3,
                  child: _Secao(
                    titulo: 'Precisa de atenção',
                    onVerTodos: () => irPara(2),
                  ),
                ),
                const SizedBox(height: 10),
                if (alertas.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppCores.roxoSuave,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tudo certo por aqui. Nada acabando, zerado ou vencendo.',
                            style: t.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final p in alertas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProdutoTile(
                        produto: p,
                        onTap: () =>
                            _abrir(context, ProdutoDetalheScreen(produto: p)),
                      ),
                    ),
                const SizedBox(height: 20),
                _Secao(
                  titulo: 'Últimas movimentações',
                  onVerTodos: () => irPara(3),
                ),
                for (final m in recentes) MovimentacaoTile(mov: m),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Painel principal: valor em estoque, indicadores e barras decorativas.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.estabelecimento,
    required this.total,
    required this.baixos,
    required this.zerados,
    required this.vencimentos,
    required this.irPara,
  });

  final String estabelecimento;
  final int total;
  final int baixos;
  final int zerados;
  final int vencimentos;
  final ValueChanged<int> irPara;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.roxo,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estabelecimento,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const _MiniBarras(),
            ],
          ),
          const SizedBox(height: 14),
          Text('Valor em estoque', style: t.bodyMedium),
          const SizedBox(height: 2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: estoque.valorEmEstoque),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              formatarPreco(v),
              style: t.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Indicador(
                  valor: total,
                  rotulo: 'produtos',
                  aoTocar: () => irPara(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Indicador(
                  valor: baixos,
                  rotulo: 'acabando',
                  cor: baixos > 0 ? AppCores.baixo : null,
                  aoTocar: () => irPara(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Indicador(
                  valor: zerados,
                  rotulo: 'zerados',
                  cor: zerados > 0 ? AppCores.zerado : null,
                  aoTocar: () => irPara(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Indicador(
                  valor: vencimentos,
                  rotulo: 'vencendo',
                  cor: vencimentos > 0 ? AppCores.baixo : null,
                  aoTocar: () => irPara(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBarras extends StatelessWidget {
  const _MiniBarras();

  @override
  Widget build(BuildContext context) {
    Widget barra(double h, Color cor) => Container(
          width: 6,
          height: h,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        barra(10, AppCores.preto),
        barra(16, AppCores.preto),
        barra(24, AppCores.branco),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.valor,
    required this.rotulo,
    required this.aoTocar,
    this.cor,
  });

  final int valor;
  final String rotulo;
  final VoidCallback aoTocar;

  /// Bolinha de aviso quando o número exige atenção.
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: AppCores.branco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(
                '$valor',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rotulo,
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (cor != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcaoRapida extends StatelessWidget {
  const _AcaoRapida({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.destaque = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: AppCores.branco,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppCores.linha),
      ),
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: destaque ? AppCores.preto : AppCores.roxo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icone,
                  color: destaque ? AppCores.branco : AppCores.preto,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rotulo,
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoSaidaRapida extends StatelessWidget {
  const _CartaoSaidaRapida({required this.produto, required this.aoVender});

  final Produto produto;
  final VoidCallback aoVender;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppCores.roxoCampo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppCores.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            produto.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${produto.quantidade} ${produto.unidade}',
                  style: t.bodySmall?.copyWith(color: AppCores.cinza),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: aoVender,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: AppCores.preto,
                    foregroundColor: AppCores.branco,
                  ),
                  child: const Text('-1'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimeirosPassos extends StatelessWidget {
  const _PrimeirosPassos();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.roxoSuave,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu estoque está vazio',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cadastre o primeiro produto (dá para escanear o código de barras) ou veja o app com dados de exemplo.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProdutoFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar primeiro produto'),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: estoque.carregarExemplo,
              child: const Text('Ver com dados de exemplo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, this.onVerTodos, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final VoidCallback? onVerTodos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  style: t.bodySmall?.copyWith(color: AppCores.cinza),
                ),
            ],
          ),
        ),
        if (onVerTodos != null)
          TextButton(onPressed: onVerTodos, child: const Text('Ver todos')),
      ],
    );
  }
}
