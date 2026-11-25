import 'package:flutter/material.dart';
import 'package:stokio/models/cliente.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/configuracoes/configuracoes_screen.dart';
import 'package:stokio/screens/fornecedores/fornecedores_screen.dart';
import 'package:stokio/screens/inventario/inventario_screen.dart';
import 'package:stokio/screens/venda/venda_rapida_screen.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: perfil,
      builder: (context, _) {
        final cliente = perfil.cliente;
        final nome = cliente?.nome ?? '';
        final inicial = nome.isEmpty ? '?' : nome[0].toUpperCase();

        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppCores.roxo,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      inicial,
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          cliente?.estabelecimento ?? '',
                          style: t.bodyMedium,
                        ),
                        if ((cliente?.email ?? '').isNotEmpty)
                          Text(
                            cliente!.email,
                            style: t.bodySmall?.copyWith(
                              color: context.cores.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _Opcao(
                icone: Icons.storefront_outlined,
                titulo: 'Dados do estabelecimento',
                onTap: () => _editar(context),
              ),
              _Opcao(
                icone: Icons.point_of_sale,
                titulo: 'Venda rápida',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VendaRapidaScreen()),
                ),
              ),
              _Opcao(
                icone: Icons.fact_check_outlined,
                titulo: 'Inventário',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventarioScreen()),
                ),
              ),
              _Opcao(
                icone: Icons.local_shipping_outlined,
                titulo: 'Fornecedores',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FornecedoresScreen()),
                ),
              ),
              _Opcao(
                icone: Icons.shopping_cart_outlined,
                titulo: 'Lista de compras',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListaComprasScreen()),
                ),
              ),
              _Opcao(
                icone: Icons.settings_outlined,
                titulo: 'Configurações e backup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfiguracoesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Seus dados ficam salvos neste aparelho. Faça um backup em Configurações para não perdê-los se trocar de celular.',
                style: t.bodySmall?.copyWith(
                  color: context.cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.cores.surface,
      builder: (_) => const _EditarPerfilSheet(),
    );
  }
}

class _EditarPerfilSheet extends StatefulWidget {
  const _EditarPerfilSheet();

  @override
  State<_EditarPerfilSheet> createState() => _EditarPerfilSheetState();
}

class _EditarPerfilSheetState extends State<_EditarPerfilSheet> {
  final _chave = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: perfil.cliente?.nome ?? '');
  late final _estabelecimento = TextEditingController(
    text: perfil.cliente?.estabelecimento ?? '',
  );
  late final _email = TextEditingController(text: perfil.cliente?.email ?? '');

  @override
  void dispose() {
    _nome.dispose();
    _estabelecimento.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

  Future<void> _salvar() async {
    if (!_chave.currentState!.validate()) return;
    await perfil.definirCliente(
      Cliente(
        nome: _nome.text.trim(),
        estabelecimento: _estabelecimento.text.trim(),
        email: _email.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + teclado),
      child: SingleChildScrollView(
        child: Form(
          key: _chave,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dados do estabelecimento',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Seu nome'),
                validator: _obrigatorio,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _estabelecimento,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do estabelecimento',
                ),
                validator: _obrigatorio,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail (opcional)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _salvar, child: const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.titulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.cores.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.cores.outlineVariant),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icone),
          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
