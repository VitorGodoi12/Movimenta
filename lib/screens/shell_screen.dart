import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/screens/alertas/alertas_screen.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
import 'package:stokio/screens/historico/historico_screen.dart';
import 'package:stokio/screens/home/home_screen.dart';
import 'package:stokio/screens/perfil/perfil_screen.dart';
import 'package:stokio/services/estoque_service.dart';

/// Estrutura principal com a barra de navegação inferior.
/// Configurações fica dentro de Perfil (e no ícone da Home).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  void _ir(int i) => setState(() => _indice = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          HomeScreen(irPara: _ir),
          const EstoqueScreen(),
          const AlertasScreen(),
          const HistoricoScreen(),
          const PerfilScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: estoque,
        builder: (context, _) {
          final qtdAlertas = estoque.alertas.length;
          return NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              _ir(i);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Estoque',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: qtdAlertas > 0,
                  label: Text('$qtdAlertas'),
                  child: const Icon(Icons.notifications_none),
                ),
                selectedIcon: Badge(
                  isLabelVisible: qtdAlertas > 0,
                  label: Text('$qtdAlertas'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'Alertas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history),
                label: 'Histórico',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          );
        },
      ),
    );
  }
}
