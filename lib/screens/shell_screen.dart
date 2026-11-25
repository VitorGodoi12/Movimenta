import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/screens/alertas/alertas_screen.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/configuracoes/configuracoes_screen.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
import 'package:stokio/screens/fornecedores/fornecedores_screen.dart';
import 'package:stokio/screens/historico/historico_screen.dart';
import 'package:stokio/screens/home/home_screen.dart';
import 'package:stokio/screens/inventario/inventario_screen.dart';
import 'package:stokio/screens/perfil/perfil_screen.dart';
import 'package:stokio/screens/operacoes_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/exportacao_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/cartao_painel.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  void _ir(int indice) {
    if (_indice == indice) return;
    HapticFeedback.selectionClick();
    setState(() => _indice = indice);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _indice == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _ir(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indice,
          children: [
            HomeScreen(abrirAba: _ir),
            const EstoqueScreen(loja: false),
            const OperacoesScreen(),
            const EstoqueScreen(loja: true),
            const _MaisScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                backgroundColor: context.cores.surface,
                indicatorColor: context.cores.primaryContainer,
                height: 74,
                selectedIndex: _indice,
                onDestinationSelected: _ir,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Início',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'Estoque',
                  ),
                  NavigationDestination(
                    icon: _AtalhoLeitor(),
                    selectedIcon: _AtalhoLeitor(),
                    label: 'Operações',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront),
                    label: 'Loja',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    label: 'Mais',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AtalhoLeitor extends StatelessWidget {
  const _AtalhoLeitor();

  @override
  Widget build(BuildContext context) => Container(
    width: 45,
    height: 45,
    decoration: BoxDecoration(
      color: AppCores.roxoAcao,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: AppCores.roxoAcao.withValues(alpha: 0.32),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 21),
  );
}

class _MaisScreen extends StatelessWidget {
  const _MaisScreen();

  List<int> _semanasDoMes(int dias) {
    final vendas = estoque.vendasPorDia(dias);
    return [
      for (var i = 0; i < vendas.length; i += 7)
        vendas.skip(i).take(7).fold(0, (soma, valor) => soma + valor),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final agora = DateTime.now();
    final destinos = <(IconData, String, Widget)>[
      (
        Icons.notifications_outlined,
        'Alertas de estoque e validade',
        const AlertasScreen(),
      ),
      (
        Icons.shopping_cart_outlined,
        'Lista de compras',
        const ListaComprasScreen(),
      ),
      (
        Icons.fact_check_outlined,
        'Inventário guiado',
        const InventarioScreen(),
      ),
      (
        Icons.local_shipping_outlined,
        'Fornecedores',
        const FornecedoresScreen(),
      ),
      (Icons.history, 'Histórico e resumo', const HistoricoScreen()),
      (
        Icons.settings_outlined,
        'Configurações e backup',
        const ConfiguracoesScreen(),
      ),
      (Icons.person_outline, 'Perfil da loja', const PerfilScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListenableBuilder(
        listenable: Listenable.merge([estoque, perfil]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          children: [
            CartaoPainel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Resumo do mês',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${agora.month.toString().padLeft(2, '0')}/${agora.year}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatarPreco(estoque.lucroEstimado(agora.day)),
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text('Lucro estimado · vendas com custo informado'),
                  const SizedBox(height: 12),
                  GraficoPainel(valores: _semanasDoMes(agora.day)),
                  const SizedBox(height: 4),
                  const Text('Unidades vendidas por semana do mês'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CartaoPainel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, (icone, titulo, tela))
                      in destinos.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(icone, color: context.cores.primary),
                      title: Text(titulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => tela),
                      ),
                    ),
                  ],
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      Icons.table_chart_outlined,
                      color: context.cores.primary,
                    ),
                    title: const Text('Exportar CSV'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final tipo = await showDialog<bool>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Exportar CSV'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Estoque'),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Histórico'),
                            ),
                          ],
                        ),
                      );
                      if (tipo != null) {
                        await ExportacaoService.compartilhar(
                          tipo ? 'estoque-stokio.csv' : 'historico-stokio.csv',
                          tipo
                              ? ExportacaoService.csvEstoque()
                              : ExportacaoService.csvHistorico(),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cores.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                perfil.ultimoBackup == null
                    ? 'Estoque local salvo neste aparelho. Nenhum backup registrado.'
                    : 'Estoque local salvo neste aparelho. Último backup em ${formatarData(perfil.ultimoBackup!)}.',
                style: t.bodyMedium?.copyWith(
                  color: context.cores.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
