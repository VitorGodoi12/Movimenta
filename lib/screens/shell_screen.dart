import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/screens/alertas/alertas_screen.dart';
import 'package:stokio/screens/configuracoes/configuracoes_screen.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
import 'package:stokio/screens/fornecedores/fornecedores_screen.dart';
import 'package:stokio/screens/historico/historico_screen.dart';
import 'package:stokio/screens/home/home_screen.dart';
import 'package:stokio/screens/inventario/inventario_screen.dart';
import 'package:stokio/screens/perfil/perfil_screen.dart';
import 'package:stokio/screens/operacoes_screen.dart';
import 'package:stokio/services/exportacao_service.dart';
import 'package:stokio/theme/app_theme.dart';
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

  Future<void> _exportar(BuildContext context) async {
    final estoqueCsv = await showDialog<bool>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: const Text('Exportar CSV'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Estoque'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Histórico'),
          ),
        ],
      ),
    );
    if (estoqueCsv == null) return;
    await ExportacaoService.compartilhar(
      estoqueCsv ? 'estoque-movimenta.csv' : 'historico-movimenta.csv',
      estoqueCsv
          ? ExportacaoService.csvEstoque()
          : ExportacaoService.csvHistorico(),
    );
  }

  @override
  Widget build(BuildContext context) {
    void abrir(Widget tela) =>
        Navigator.push<void>(context, MaterialPageRoute(builder: (_) => tela));
    final grupos = <(String, List<(IconData, String, VoidCallback)>)>[
      (
        'Acompanhamento',
        [
          (
            Icons.history_rounded,
            'Histórico e resumo',
            () => abrir(const HistoricoScreen()),
          ),
          (
            Icons.notifications_outlined,
            'Alertas de estoque e validade',
            () => abrir(const AlertasScreen()),
          ),
          (
            Icons.fact_check_outlined,
            'Inventário guiado',
            () => abrir(const InventarioScreen()),
          ),
        ],
      ),
      (
        'Organização',
        [
          (
            Icons.local_shipping_outlined,
            'Fornecedores',
            () => abrir(const FornecedoresScreen()),
          ),
          (
            Icons.table_chart_outlined,
            'Exportar CSV',
            () => _exportar(context),
          ),
        ],
      ),
      (
        'Preferências',
        [
          (
            Icons.settings_outlined,
            'Configurações e backup',
            () => abrir(const ConfiguracoesScreen()),
          ),
          (
            Icons.person_outline,
            'Perfil da loja',
            () => abrir(const PerfilScreen()),
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        children: [
          for (final (titulo, destinos) in grupos) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            CartaoPainel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, (icone, rotulo, acao))
                      in destinos.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 54, endIndent: 14),
                    ListTile(
                      leading: Icon(icone, color: context.cores.primary),
                      title: Text(rotulo),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: acao,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
