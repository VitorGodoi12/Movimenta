import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/models/cliente.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/widgets/avatar_perfil.dart';
import 'package:stokio/widgets/cartao_painel.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const _canal = MethodChannel('movimenta/perfil');
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: perfil.cliente?.nome ?? '');
  late final _apelido = TextEditingController(
    text: perfil.cliente?.apelido ?? '',
  );
  late final _loja = TextEditingController(
    text: perfil.cliente?.estabelecimento ?? '',
  );
  late final _email = TextEditingController(text: perfil.cliente?.email ?? '');
  late String? _foto = perfil.cliente?.foto;
  late int _cor = (perfil.cliente?.corAvatar ?? 0).clamp(
    0,
    coresAvatar.length - 1,
  );
  bool _escolhendo = false;
  bool _salvando = false;

  Cliente get _rascunho => Cliente(
    nome: _nome.text.trim(),
    apelido: _apelido.text.trim(),
    estabelecimento: _loja.text.trim(),
    email: _email.text.trim(),
    foto: _foto,
    corAvatar: _cor,
  );

  Future<void> _escolherFoto() async {
    setState(() => _escolhendo = true);
    try {
      final bytes = await _canal.invokeMethod<Uint8List>('escolherFoto');
      if (!mounted || bytes == null) return;
      if (bytes.isEmpty || bytes.length > 300000) {
        throw PlatformException(
          code: 'imagem',
          message: 'A foto não pôde ser usada.',
        );
      }
      setState(() => _foto = base64Encode(bytes));
    } on PlatformException catch (erro) {
      if (mounted) _aviso(erro.message ?? 'Não foi possível abrir a foto.');
    } on MissingPluginException {
      if (mounted) _aviso('A seleção de foto está disponível no app Android.');
    } finally {
      if (mounted) setState(() => _escolhendo = false);
    }
  }

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await perfil.definirCliente(_rascunho);
      if (mounted) Navigator.pop(context);
    } on StateError {
      if (mounted) _aviso('Não foi possível salvar o perfil. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String? _obrigatorio(String? valor) =>
      (valor ?? '').trim().isEmpty ? 'Preencha este campo.' : null;

  @override
  void dispose() {
    for (final controle in [_nome, _apelido, _loja, _email]) {
      controle.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fotoDisponivel =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CartaoPainel(
                child: Column(
                  children: [
                    AvatarPerfil(cliente: _rascunho, tamanho: 88),
                    if (fotoDisponivel)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _escolhendo ? null : _escolherFoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _foto == null ? 'Escolher foto' : 'Trocar foto',
                            ),
                          ),
                          if (_foto != null)
                            TextButton(
                              onPressed: () => setState(() => _foto = null),
                              child: const Text('Remover foto'),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Cor da inicial',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (i, (nome, cor)) in coresAvatar.indexed)
                          ChoiceChip(
                            avatar: CircleAvatar(backgroundColor: cor),
                            label: Text(nome),
                            selected: _cor == i,
                            onSelected: (_) => setState(() => _cor = i),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CartaoPainel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nome,
                      validator: _obrigatorio,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Seu nome',
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apelido,
                      maxLength: 32,
                      decoration: const InputDecoration(
                        labelText: 'Apelido no app (opcional)',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _loja,
                      validator: _obrigatorio,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Nome do estabelecimento',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _salvando || _escolhendo ? null : _salvar,
                child: const Text('Salvar perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
