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
import 'package:stokio/screens/venda/venda_rapida_screen.dart';
import 'package:stokio/services/estoque_service.dart';

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
            HomeScreen(abrirEstoque: () => _ir(1), abrirVenda: () => _ir(2)),
            const EstoqueScreen(),
            VendaRapidaScreen(incorporada: true, ativa: _indice == 2),
            const _MaisScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
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
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'Vender',
            ),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
          ],
        ),
      ),
    );
  }
}

class _MaisScreen extends StatelessWidget {
  const _MaisScreen();

  @override
  Widget build(BuildContext context) {
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
        listenable: estoque,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final (icone, titulo, tela) in destinos)
              ListTile(
                leading: Icon(icone),
                title: Text(titulo),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => tela),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
