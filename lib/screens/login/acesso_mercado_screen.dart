import 'package:stokio/widgets/painel_acesso.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stokio/screens/mercado/mercado_screen.dart';
import 'package:stokio/services/mercado_firebase.dart';

class AcessoMercadoScreen extends StatelessWidget {
  const AcessoMercadoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!MercadoFirebase.ativo) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Configure o Firebase para usar o mercado compartilhado.',
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: MercadoFirebase.auth.userChanges(),
      builder: (context, estado) {
        if (estado.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final usuario = estado.data;
        if (usuario == null) return const _Autenticacao();
        if (!usuario.emailVerified) return _VerificarEmail(usuario: usuario);
        return _Vinculo(key: ValueKey(usuario.uid), usuario: usuario);
      },
    );
  }
}

class _VerificarEmail extends StatelessWidget {
  const _VerificarEmail({required this.usuario});
  final User usuario;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirme seu e-mail')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Abra o link enviado ao seu e-mail e volte para continuar.'),
        TextButton(
          onPressed: () => usuario.reload(),
          child: const Text('Já confirmei'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await usuario.sendEmailVerification();
              if (context.mounted) _mensagem(context, 'Verificação enviada.');
            } on FirebaseAuthException catch (erro) {
              if (context.mounted)
                _mensagem(context, erro.message ?? 'Tente mais tarde.');
            }
          },
          child: const Text('Reenviar verificação'),
        ),
        TextButton(
          onPressed: MercadoFirebase.auth.signOut,
          child: const Text('Sair'),
        ),
      ],
    ),
  );
}

void _mensagem(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

class _Autenticacao extends StatefulWidget {
  const _Autenticacao();
  @override
  State<_Autenticacao> createState() => _AutenticacaoState();
}

class _AutenticacaoState extends State<_Autenticacao> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _criar = false;
  bool _visivel = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _executar(Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await acao();
    } on FirebaseAuthException catch (erro) {
      if (mounted)
        _mensagem(
          context,
          erro.message ?? 'Confira seus dados e tente novamente.',
        );
    } catch (_) {
      if (mounted)
        _mensagem(
          context,
          'Não foi possível entrar. Confira a conexão ou tente outro método.',
        );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  bool _emailValido(String valor) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor);

  @override
  Widget build(BuildContext context) => PainelAcesso(
    titulo: _criar ? 'Crie sua conta' : 'Bem-vindo de volta',
    descricao: _criar
        ? 'Use seu e-mail ou Google para começar.'
        : 'Entre para acessar o seu mercado.',
    child: AutofillGroup(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => _emailValido(v?.trim() ?? '')
                  ? null
                  : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senha,
              obscureText: !_visivel,
              autofillHints: [
                _criar ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _visivel ? 'Ocultar senha' : 'Mostrar senha',
                  onPressed: () => setState(() => _visivel = !_visivel),
                  icon: Icon(
                    _visivel ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) =>
                  (v?.length ?? 0) >= 6 ? null : 'Use pelo menos 6 caracteres.',
            ),
            if (_ocupado) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      if (!_form.currentState!.validate()) return;
                      _executar(() async {
                        if (_criar) {
                          final credencial = await MercadoFirebase.auth
                              .createUserWithEmailAndPassword(
                                email: _email.text.trim(),
                                password: _senha.text,
                              );
                          await credencial.user?.sendEmailVerification();
                        } else {
                          await MercadoFirebase.auth.signInWithEmailAndPassword(
                            email: _email.text.trim(),
                            password: _senha.text,
                          );
                        }
                      });
                    },
              child: Text(_criar ? 'Continuar cadastro' : 'Entrar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _ocupado
                  ? null
                  : () => _executar(MercadoFirebase.entrarGoogle),
              child: const Text('Entrar com o Google'),
            ),
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      final email = _email.text.trim();
                      if (!_emailValido(email)) {
                        _mensagem(
                          context,
                          'Preencha o e-mail para recuperar a senha.',
                        );
                        return;
                      }
                      _executar(() async {
                        try {
                          await MercadoFirebase.auth.sendPasswordResetEmail(
                            email: email,
                          );
                        } on FirebaseAuthException catch (erro) {
                          if (erro.code != 'user-not-found') rethrow;
                        }
                        if (mounted)
                          _mensagem(
                            context,
                            'Se houver uma conta para este e-mail, você receberá o link.',
                          );
                      });
                    },
              child: const Text('Esqueci minha senha'),
            ),
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => setState(() => _criar = !_criar),
              child: Text(_criar ? 'Já tenho conta' : 'Criar conta'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Vinculo extends StatefulWidget {
  const _Vinculo({super.key, required this.usuario});
  final User usuario;
  @override
  State<_Vinculo> createState() => _VinculoState();
}

class _VinculoState extends State<_Vinculo> {
  late final _ref = MercadoFirebase.usuario(widget.usuario.uid);
  late final _vinculo = _ref.snapshots();
  String? _convite;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _vinculo,
    builder: (context, valor) {
      if (valor.hasError)
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: MercadoFirebase.auth.signOut,
              child: const Text('Falha ao consultar o perfil. Sair'),
            ),
          ),
        );
      if (!valor.hasData)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final perfil = valor.data!.data();
      if (_convite case final codigo?) {
        return Scaffold(
          appBar: AppBar(title: const Text('Seu mercado está pronto')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(codigo, style: Theme.of(context).textTheme.headlineMedium),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: codigo));
                  if (context.mounted) _mensagem(context, 'Código copiado.');
                },
                child: const Text('Copiar código'),
              ),
              TextButton(
                onPressed: () => Share.share(codigo),
                child: const Text('Compartilhar código'),
              ),
              FilledButton(
                onPressed: () => setState(() => _convite = null),
                child: const Text('Abrir mercado'),
              ),
            ],
          ),
        );
      }
      if (perfil?['status'] == 'ativo') {
        return MercadoScreen(
          key: ValueKey([perfil!['mercadoId'], perfil['cargo']].join(':')),
          mercadoId: perfil['mercadoId'] as String,
          cargo: perfil['cargo'] as String,
        );
      }
      if (perfil?['status'] == 'pendente') {
        return Scaffold(
          appBar: AppBar(title: const Text('Aguardando aprovação')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Aguardando aprovação do dono ou gerente.'),
              TextButton(
                onPressed: () async {
                  try {
                    await _ref.get(const GetOptions(source: Source.server));
                  } catch (_) {
                    if (context.mounted)
                      _mensagem(context, 'Confira a conexão.');
                  }
                },
                child: const Text('Atualizar status'),
              ),
              TextButton(
                onPressed: MercadoFirebase.auth.signOut,
                child: const Text('Sair'),
              ),
            ],
          ),
        );
      }
      return _Completar(
        usuario: widget.usuario,
        convite: (codigo) => setState(() => _convite = codigo),
      );
    },
  );
}

class _Completar extends StatefulWidget {
  const _Completar({required this.usuario, required this.convite});
  final User usuario;
  final ValueChanged<String> convite;
  @override
  State<_Completar> createState() => _CompletarState();
}

class _CompletarState extends State<_Completar> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.usuario.displayName);
  final _telefone = TextEditingController();
  final _mercado = TextEditingController();
  final _endereco = TextEditingController();
  final _busca = TextEditingController();
  bool? _dono;
  bool _buscarEmail = false;
  bool _ocupado = false;

  @override
  void dispose() {
    for (final c in [_nome, _telefone, _mercado, _endereco, _busca]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_ocupado || _dono == null || !_form.currentState!.validate()) return;
    setState(() => _ocupado = true);
    try {
      final dados = {
        'nome': _nome.text.trim(),
        'telefone': _telefone.text.trim(),
      };
      if (_dono!) {
        final resposta = await MercadoFirebase.chamar('criarMercado', {
          ...dados,
          'mercado': _mercado.text.trim(),
          'endereco': _endereco.text.trim(),
        });
        if (mounted && resposta['codigo'] is String)
          widget.convite(resposta['codigo'] as String);
      } else {
        final busca = {_buscarEmail ? 'email' : 'codigo': _busca.text.trim()};
        final mercado = await MercadoFirebase.chamar('buscarMercado', busca);
        if (!mounted) return;
        if (mercado == null) {
          _mensagem(context, 'Mercado não encontrado.');
          return;
        }
        final nome = mercado['nome'] as String;
        final confirmou = await showDialog<bool>(
          context: context,
          builder: (dialogo) => AlertDialog(
            title: Text(nome),
            content: const Text('Solicitar acesso a este mercado?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogo, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogo, true),
                child: const Text('Solicitar'),
              ),
            ],
          ),
        );
        if (confirmou == true)
          await MercadoFirebase.chamar('solicitarAcesso', {
            ...dados,
            ...busca,
            'nomeConfirmado': nome,
          });
      }
    } catch (erro) {
      if (mounted)
        _mensagem(context, 'Confira os dados ou a conexão e tente novamente.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String? _obrigatorio(String? valor) =>
      (valor ?? '').trim().isEmpty ? 'Preencha este campo.' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Completar cadastro'),
      actions: [
        TextButton(
          onPressed: MercadoFirebase.auth.signOut,
          child: const Text('Sair'),
        ),
      ],
    ),
    body: Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (dono, titulo, icone) in const [
            (true, 'Sou Dono de Mercado', Icons.storefront),
            (false, 'Sou Funcionário', Icons.badge_outlined),
          ])
            Card(
              child: ListTile(
                leading: Icon(icone),
                title: Text(titulo),
                selected: _dono == dono,
                trailing: _dono == dono ? const Icon(Icons.check_circle) : null,
                onTap: () => setState(() => _dono = dono),
              ),
            ),
          if (_dono != null) ...[
            const SizedBox(height: 12),
            Text(widget.usuario.email ?? ''),
            TextFormField(
              controller: _nome,
              validator: _obrigatorio,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                hintText: '(00) 00000-0000',
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((antes, depois) {
                  final n = depois.text.replaceAll(RegExp(r'\D'), '');
                  if (n.length > 11) return antes;
                  final valor = n.length <= 2
                      ? n
                      : '(' +
                            n.substring(0, 2) +
                            ') ' +
                            (n.length <= 7
                                ? n.substring(2)
                                : n.substring(2, 7) + '-' + n.substring(7));
                  return TextEditingValue(
                    text: valor,
                    selection: TextSelection.collapsed(offset: valor.length),
                  );
                }),
              ],
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp(r'\D'), '').length == 11
                  ? null
                  : 'Informe 11 dígitos com DDD.',
            ),
            const SizedBox(height: 8),
            if (_dono!) ...[
              TextFormField(
                controller: _mercado,
                validator: _obrigatorio,
                decoration: const InputDecoration(labelText: 'Nome do mercado'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _endereco,
                decoration: const InputDecoration(
                  labelText: 'Endereço (opcional)',
                ),
              ),
            ] else ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Tenho o código')),
                  ButtonSegment(value: true, label: Text('E-mail do dono')),
                ],
                selected: {_buscarEmail},
                onSelectionChanged: (opcoes) => setState(() {
                  _buscarEmail = opcoes.single;
                  _busca.clear();
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _busca,
                validator: _obrigatorio,
                decoration: InputDecoration(
                  labelText: _buscarEmail
                      ? 'E-mail do dono'
                      : 'Código do mercado',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_ocupado) const LinearProgressIndicator(),
            FilledButton(
              onPressed: _ocupado ? null : _salvar,
              child: Text(_dono! ? 'Criar mercado' : 'Localizar mercado'),
            ),
          ],
        ],
      ),
    ),
  );
}
