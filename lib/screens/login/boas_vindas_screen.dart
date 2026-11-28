import 'package:stokio/widgets/painel_acesso.dart';
import 'package:flutter/material.dart';
import 'package:stokio/models/cliente.dart';
import 'package:stokio/screens/shell_screen.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';

/// Primeira tela do app: cria o perfil local do estabelecimento.
/// Quando o login online existir, é aqui que ele entra.
class BoasVindasScreen extends StatefulWidget {
  const BoasVindasScreen({super.key});

  @override
  State<BoasVindasScreen> createState() => _BoasVindasScreenState();
}

class _BoasVindasScreenState extends State<BoasVindasScreen> {
  final _chave = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _estabelecimento = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _estabelecimento.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

  Future<void> _comecar() async {
    if (!_chave.currentState!.validate()) return;
    await perfil.definirCliente(
      Cliente(
        nome: _nome.text.trim(),
        estabelecimento: _estabelecimento.text.trim(),
        email: _email.text.trim(),
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PainelAcesso(
      titulo: 'Bem-vindo ao Movimenta',
      descricao: 'Configure seu perfil para começar a organizar o estoque.',
      child: Form(
        key: _chave,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vamos configurar o básico',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Seus dados ficam salvos neste aparelho.',
              style: t.bodyMedium?.copyWith(
                color: context.cores.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Seu nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _estabelecimento,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do estabelecimento',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail (opcional)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _comecar,
              child: const Text('Começar a usar'),
            ),
          ],
        ),
      ),
    );
  }
}
