import 'package:flutter/material.dart';
import 'package:stokio/models/cliente.dart';
import 'package:stokio/screens/shell_screen.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/marca_stokio.dart';

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
    final topo = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, topo + 24, 24, 24),
              decoration: const BoxDecoration(
                color: AppCores.roxo,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MarcaStokio(),
                  const SizedBox(height: 28),
                  Text(
                    'Seu estoque,\nsempre em dia.',
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Controle produtos, validades, entradas e saídas direto do celular.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const _BarrasDecorativas(),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _chave,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vamos configurar o básico',
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Seus dados ficam salvos neste aparelho.',
                          style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nome,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Seu nome',
                          ),
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
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _comecar,
                          child: const Text('Começar a usar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarrasDecorativas extends StatelessWidget {
  const _BarrasDecorativas();

  static const _alturas = [34.0, 62.0, 48.0, 86.0, 70.0, 104.0, 58.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in _alturas)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: AppCores.branco,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
