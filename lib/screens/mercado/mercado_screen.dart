import 'package:stokio/models/foto_cadastro.dart';
import 'package:stokio/services/leitura_foto.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/screens/shell_screen.dart';
import 'package:stokio/services/fila_entradas_mercado.dart';
import 'package:stokio/services/mercado_firebase.dart';
import 'package:stokio/utils/codigo_produto.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/campo_data.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

class MercadoScreen extends StatefulWidget {
  const MercadoScreen({
    super.key,
    required this.mercadoId,
    required this.cargo,
  });

  final String mercadoId;
  final String cargo;

  @override
  State<MercadoScreen> createState() => _MercadoScreenState();
}

class _MercadoScreenState extends State<MercadoScreen> {
  late final _mercado = MercadoFirebase.mercado(widget.mercadoId);
  late final _fila = FilaEntradasMercado(
    MercadoFirebase.auth.currentUser!.uid,
    widget.mercadoId,
  );
  bool get _gerencia => widget.cargo == 'gerente' || widget.cargo == 'dono';
  late final _dados = _mercado.snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _produtos = _gerencia
      ? _mercado.collection('produtos').snapshots()
      : _mercado
            .collection('produtos')
            .where('naLoja', isEqualTo: true)
            .snapshots();

  @override
  void initState() {
    super.initState();
    if (_gerencia && _fila.pendentes > 0)
      unawaited(_sincronizar(avisar: false));
  }

  void _aviso(String texto) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _sincronizar({bool avisar = true}) async {
    try {
      await _fila.sincronizar();
      if (avisar) _aviso('Entradas sincronizadas.');
    } catch (_) {
      if (avisar)
        _aviso('Ainda há entradas pendentes. Confira a conexão e o vínculo.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _novaEntrada([String? codigo]) async {
    final entradaId = _mercado.collection('entradas').doc().id;
    String corredorId = '';
    try {
      final corredores = await _mercado
          .collection('corredores')
          .get()
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      if (corredores.docs.isNotEmpty) {
        final escolha = await showDialog<String>(
          context: context,
          builder: (dialogo) => SimpleDialog(
            title: const Text('Corredor da entrada'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogo, ''),
                child: const Text('Sem corredor'),
              ),
              for (final corredor in corredores.docs)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogo, corredor.id),
                  child: Text(corredor.data()['nome'] as String),
                ),
            ],
          ),
        );
        if (escolha == null) return;
        corredorId = escolha;
      }
    } catch (_) {
      // Sem conexão, a entrada pode ser preparada sem selecionar corredor.
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoFormScreen(
          codigoInicial: codigo,
          confirmarMercado: (entrada) => _fila.enviar({
            ...entrada.paraDados(),
            'entradaId': entradaId,
            'mercadoId': widget.mercadoId,
            'corredorId': corredorId,
          }),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _bipar() async {
    final codigo = await lerCodigo(context);
    if (codigo == null || !mounted) return;
    if (_gerencia) {
      await _novaEntrada(codigo);
      return;
    }
    try {
      final produto = await _mercado
          .collection('produtos')
          .doc('cod_' + chaveCodigoProduto(codigo))
          .get();
      if (!mounted) return;
      if (!produto.exists || produto.data()?['naLoja'] != true) {
        _aviso('Produto indisponível na Loja.');
        return;
      }
      _abrir(_ProdutoMercado(referencia: produto.reference, gerencia: false));
    } catch (_) {
      _aviso('Não foi possível localizar o produto na Loja.');
    }
  }

  void _abrir(Widget tela) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => tela));

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _dados,
    builder: (context, mercado) {
      final info = mercado.data?.data();
      return Scaffold(
        appBar: AppBar(
          title: Text(info?['nome'] as String? ?? 'Mercado'),
          actions: [
            IconButton(
              tooltip: 'Bipar produto',
              onPressed: _bipar,
              icon: const Icon(Icons.qr_code_scanner),
            ),
            PopupMenuButton<String>(
              onSelected: (opcao) async {
                if (opcao == 'equipe')
                  _abrir(_Equipe(mercadoId: widget.mercadoId));
                if (opcao == 'corredores')
                  _abrir(_Corredores(mercadoId: widget.mercadoId));
                if (opcao == 'local') _abrir(const ShellScreen());
                final codigo = info?['codigoConvite'];
                if (opcao == 'convite' && codigo is String) {
                  await Clipboard.setData(ClipboardData(text: codigo));
                  _aviso('Código copiado: ' + codigo);
                  if (mounted) await Share.share(codigo);
                }
                if (opcao == 'sair') await MercadoFirebase.auth.signOut();
              },
              itemBuilder: (_) => [
                if (_gerencia) ...[
                  const PopupMenuItem(
                    value: 'equipe',
                    child: Text('Minha Equipe'),
                  ),
                  const PopupMenuItem(
                    value: 'corredores',
                    child: Text('Corredores'),
                  ),
                  const PopupMenuItem(
                    value: 'convite',
                    child: Text('Código do mercado'),
                  ),
                ],
                if (widget.cargo == 'dono')
                  const PopupMenuItem(
                    value: 'local',
                    child: Text('Estoque deste aparelho'),
                  ),
                const PopupMenuItem(value: 'sair', child: Text('Sair')),
              ],
            ),
          ],
        ),
        floatingActionButton: _gerencia
            ? FloatingActionButton.extended(
                onPressed: _novaEntrada,
                icon: const Icon(Icons.add),
                label: const Text('Nova entrada'),
              )
            : null,
        body: Column(
          children: [
            if (_gerencia && _fila.pendentes > 0)
              ListTile(
                subtitle: const Text(
                  'Salvo no dispositivo, aguardando sincronização',
                ),
                title: Text(_fila.pendentes.toString() + ' entradas pendentes'),
                trailing: TextButton(
                  onPressed: _sincronizar,
                  child: const Text('Sincronizar'),
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _produtos,
                builder: (context, dados) {
                  if (dados.hasError)
                    return const Center(
                      child: Text('Não foi possível consultar os produtos.'),
                    );
                  if (!dados.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = dados.data!.docs;
                  if (docs.isEmpty)
                    return const Center(
                      child: Text('Nenhum produto disponível.'),
                    );
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final produto = docs[i];
                      final d = produto.data();
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(d['nome'] as String? ?? ''),
                        subtitle: Text(
                          formatarPreco((d['preco'] as num?)?.toDouble() ?? 0),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrir(
                          _ProdutoMercado(
                            referencia: produto.reference,
                            gerencia: _gerencia,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ProdutoMercado extends StatefulWidget {
  const _ProdutoMercado({required this.referencia, required this.gerencia});
  final DocumentReference<Map<String, dynamic>> referencia;
  final bool gerencia;
  @override
  State<_ProdutoMercado> createState() => _ProdutoMercadoState();
}

class _ProdutoMercadoState extends State<_ProdutoMercado> {
  late final _ficha = widget.referencia.snapshots();
  late final _lotes =
      (widget.gerencia
              ? widget.referencia.collection('lotes')
              : widget.referencia
                    .collection('lotes')
                    .where('destino', isEqualTo: 'loja'))
          .snapshots(includeMetadataChanges: true);
  static const _diasAviso = 7;

  void _aviso(String texto) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
  }

  void _atualizar(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, Object?> campos,
  ) {
    unawaited(
      ref
          .update({...campos, 'atualizadoEm': FieldValue.serverTimestamp()})
          .then(
            (_) => _aviso('Sincronizado.'),
            onError: (Object _) =>
                _aviso('Não foi possível salvar a alteração.'),
          ),
    );
    _aviso(
      'Alteração enviada. Pode aguardar sincronização se estiver offline.',
    );
  }

  Future<void> _editarPreco(double preco) async {
    final novo = await showDialog<double>(
      context: context,
      builder: (_) => _EditarValor(preco: preco),
    );
    if (novo != null && mounted) _atualizar(widget.referencia, {'preco': novo});
  }

  Future<void> _editarData(_Doc lote, DateTime? anterior) async {
    final edicao = await showDialog<(bool, DateTime?)>(
      context: context,
      builder: (_) => _EditarValidade(anterior: anterior),
    );
    if (edicao != null && mounted) {
      final data = edicao.$2;
      _atualizar(lote.reference, {
        'validade': data == null ? null : Timestamp.fromDate(data),
      });
    }
  }

  (String, Color) _validade(DateTime? data) {
    if (data == null) return ('Validade não informada', Colors.blueGrey);
    final dias = -diasDesde(data);
    if (dias < 0) return ('Vencido', Colors.red);
    if (dias <= _diasAviso) return ('Próximo do vencimento', Colors.amber);
    return ('Dentro do prazo', Colors.green);
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ficha,
        builder: (context, ficha) {
          final d = ficha.data?.data();
          return Scaffold(
            appBar: AppBar(title: Text(d?['nome'] as String? ?? 'Produto')),
            body: d == null
                ? Center(
                    child: Text(
                      ficha.hasError
                          ? 'Acesso indisponível.'
                          : 'Carregando produto…',
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _lotes,
                    builder: (context, snapshot) {
                      final preco = (d['preco'] as num?)?.toDouble() ?? 0;
                      final lotes = snapshot.data?.docs ?? const <_Doc>[];
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ListTile(
                            title: const Text('Preço'),
                            subtitle: Text(formatarPreco(preco)),
                            trailing: const Icon(Icons.edit),
                            onTap: () => _editarPreco(preco),
                          ),
                          if (snapshot.data?.metadata.hasPendingWrites == true)
                            const Text(
                              'Salvo no dispositivo, aguardando sincronização',
                            ),
                          if (snapshot.hasError)
                            const Text('Não foi possível consultar os lotes.'),
                          for (final lote in lotes)
                            Builder(
                              builder: (context) {
                                final dados = lote.data();
                                final data = (dados['validade'] as Timestamp?)
                                    ?.toDate();
                                final (rotulo, cor) = _validade(data);
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.event_outlined,
                                      color: cor,
                                    ),
                                    title: Text(rotulo),
                                    subtitle: Text(
                                      (data == null
                                              ? ''
                                              : formatarData(data) + ' · ') +
                                          dados['quantidade'].toString() +
                                          ' · ' +
                                          dados['destino'].toString(),
                                    ),
                                    trailing: const Icon(Icons.edit_outlined),
                                    onTap: () => _editarData(lote, data),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
          );
        },
      );
}

class _EditarValidade extends StatefulWidget {
  const _EditarValidade({required this.anterior});
  final DateTime? anterior;
  @override
  State<_EditarValidade> createState() => _EditarValidadeState();
}

class _EditarValidadeState extends State<_EditarValidade> {
  final _form = GlobalKey<FormState>();
  late DateTime? _data = widget.anterior;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Validade do lote'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CampoData(
            rotulo: 'Validade',
            valor: _data,
            aoMudar: (valor) => _data = valor,
          ),
          TextButton.icon(
            onPressed: () async {
              final escolha = await _escolherDaFoto(
                context,
                FinalidadeFoto.validade,
                (foto) => foto.validades,
                (data) => data.rotulo,
              );
              if (escolha != null && mounted)
                setState(() => _data = escolha.data);
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Fotografar validade'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(context, (true, _data));
        },
        child: const Text('Salvar alterações'),
      ),
    ],
  );
}

Future<T?> _escolherDaFoto<T>(
  BuildContext context,
  FinalidadeFoto finalidade,
  List<T> Function(FotoCadastro) extrair,
  String Function(T) rotulo,
) async {
  try {
    final foto = await LeituraFoto.capturar(finalidade);
    if (!context.mounted || foto == null) return null;
    final valores = extrair(foto);
    if (valores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto ilegível. Tente novamente ou digite o valor.'),
        ),
      );
      return null;
    }
    return showDialog<T>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: const Text('Conferir leitura'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Image.memory(foto.imagem, height: 100),
          ),
          for (final valor in valores)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogo, valor),
              child: Text(rotulo(valor)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Manter valor anterior'),
          ),
        ],
      ),
    );
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível usar a câmera.')),
      );
    return null;
  }
}

class _EditarValor extends StatefulWidget {
  const _EditarValor({required this.preco});
  final double preco;
  @override
  State<_EditarValor> createState() => _EditarValorState();
}

class _EditarValorState extends State<_EditarValor> {
  late final _campo = TextEditingController(
    text: widget.preco.toStringAsFixed(2).replaceAll('.', ','),
  );
  final _form = GlobalKey<FormState>();
  double? get _valor =>
      double.tryParse(_campo.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar preço'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _campo,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (_) {
          final v = _valor;
          return v != null && v.isFinite && v >= 0 && v <= 9999999
              ? null
              : 'Informe um preço válido.';
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) Navigator.pop(context, _valor);
        },
        child: const Text('Salvar alterações'),
      ),
    ],
  );
}

class _Equipe extends StatelessWidget {
  const _Equipe({required this.mercadoId});
  final String mercadoId;

  Future<void> _acao(BuildContext context, _Doc membro, String acao) async {
    String? cargo;
    if (acao == 'aprovar' || acao == 'cargo') {
      cargo = await showDialog<String>(
        context: context,
        builder: (dialogo) => SimpleDialog(
          title: const Text('Escolher cargo'),
          children: [
            for (final cargo in ['funcionario', 'gerente', 'dono'])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogo, cargo),
                child: Text(cargo),
              ),
          ],
        ),
      );
      if (cargo == null) return;
    }
    try {
      await MercadoFirebase.chamar('alterarEquipe', {
        'uid': membro.id,
        'acao': acao,
        'cargo': cargo,
      });
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar o vínculo.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Minha Equipe'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Solicitações pendentes'),
            Tab(text: 'Membros ativos'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: MercadoFirebase.banco
            .collection('users')
            .where('mercadoId', isEqualTo: mercadoId)
            .snapshots(),
        builder: (context, estado) {
          if (estado.hasError)
            return const Center(child: Text('A equipe não está disponível.'));
          if (!estado.hasData)
            return const Center(child: CircularProgressIndicator());
          final equipe = estado.data!.docs;
          return TabBarView(
            children: [
              for (final status in ['pendente', 'ativo'])
                ListView(
                  children: [
                    for (final membro in equipe.where(
                      (e) => e.data()['status'] == status,
                    ))
                      ListTile(
                        title: Text(membro.data()['nome'] as String? ?? ''),
                        subtitle: Text(membro.data()['cargo'] as String? ?? ''),
                        trailing:
                            membro.id == MercadoFirebase.auth.currentUser?.uid
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (acao) =>
                                    _acao(context, membro, acao),
                                itemBuilder: (_) => status == 'pendente'
                                    ? const [
                                        PopupMenuItem(
                                          value: 'aprovar',
                                          child: Text('Aprovar'),
                                        ),
                                        PopupMenuItem(
                                          value: 'recusar',
                                          child: Text('Recusar'),
                                        ),
                                      ]
                                    : const [
                                        PopupMenuItem(
                                          value: 'cargo',
                                          child: Text('Alterar cargo'),
                                        ),
                                        PopupMenuItem(
                                          value: 'remover',
                                          child: Text('Remover'),
                                        ),
                                      ],
                              ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _Corredores extends StatelessWidget {
  const _Corredores({required this.mercadoId});
  final String mercadoId;

  CollectionReference<Map<String, dynamic>> get _colecao =>
      MercadoFirebase.mercado(mercadoId).collection('corredores');

  Future<void> _editar(BuildContext context, [_Doc? corredor]) async {
    try {
      final equipe = await MercadoFirebase.banco
          .collection('users')
          .where('mercadoId', isEqualTo: mercadoId)
          .get();
      if (!context.mounted) return;
      final resultado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _EditarCorredor(
          inicial: corredor?.data(),
          membros: equipe.docs
              .where((m) => m.data()['status'] == 'ativo')
              .toList(),
        ),
      );
      if (resultado != null)
        await (corredor?.reference ?? _colecao.doc()).set(resultado);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível alterar o corredor.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corredores')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _editar(context),
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _colecao.snapshots(),
      builder: (context, dados) {
        if (dados.hasError)
          return const Center(child: Text('Corredores indisponíveis.'));
        if (!dados.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            for (final corredor in dados.data!.docs)
              ListTile(
                title: Text(corredor.data()['nome'] as String),
                subtitle: Text(
                  corredor.data()['funcionarioResponsavelNome'] as String? ??
                      '',
                ),
                onTap: () => _editar(context, corredor),
                trailing: IconButton(
                  tooltip: 'Excluir corredor',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final excluir = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Excluir corredor?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (excluir == true) {
                      try {
                        await corredor.reference.delete();
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não foi possível excluir o corredor.',
                              ),
                            ),
                          );
                      }
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _EditarCorredor extends StatefulWidget {
  const _EditarCorredor({required this.inicial, required this.membros});
  final Map<String, dynamic>? inicial;
  final List<_Doc> membros;
  @override
  State<_EditarCorredor> createState() => _EditarCorredorState();
}

class _EditarCorredorState extends State<_EditarCorredor> {
  late final _nome = TextEditingController(
    text: widget.inicial?['nome'] as String?,
  );
  late var _id =
      widget.membros.any(
        (m) => m.id == widget.inicial?['funcionarioResponsavelId'],
      )
      ? widget.inicial!['funcionarioResponsavelId'] as String
      : '';
  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar corredor'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nome,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Nome do corredor'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Responsável'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem responsável')),
              for (final membro in widget.membros)
                DropdownMenuItem(
                  value: membro.id,
                  child: Text(
                    membro.data()['nome'] as String,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _id = id ?? ''),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _nome.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, {
                'nome': _nome.text.trim(),
                'funcionarioResponsavelId': _id,
                'funcionarioResponsavelNome': _id.isEmpty
                    ? ''
                    : widget.membros
                          .firstWhere((m) => m.id == _id)
                          .data()['nome'],
              }),
        child: const Text('Salvar'),
      ),
    ],
  );
}
