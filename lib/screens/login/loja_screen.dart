import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/services/loja_api.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/utils/formatadores.dart';

class LojaScreen extends StatefulWidget {
  const LojaScreen({super.key});
  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final _endereco = TextEditingController(
    text: const String.fromEnvironment('STOKIO_API_URL'),
  );
  LojaApi? _api;
  bool _ocupado = false;
  List<Map<String, dynamic>> _lojas = [];

  @override
  void dispose() {
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _executar(Future<void> Function() operacao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await operacao();
    } catch (erro) {
      if (mounted) {
        if (_api?.token == null) _api = null;
        _mensagem(context, _erro(erro));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _atualizar() async {
    final lojas = registros(await _api!.chamar('stores'), 'stores');
    if (mounted) setState(() => _lojas = lojas);
  }

  Future<void> _autenticar({bool? dono}) async {
    final dados = await _formulario(
      context,
      dono == null ? 'Entrar' : 'Criar conta',
      [
        if (dono != null) ('name', dono ? 'Nome do dono' : 'Nome', false),
        if (dono == true) ...[
          ('market', 'Nome do mercado', false),
          ('address', 'Endereço do mercado', true),
        ],
        ('email', dono == true ? 'E-mail para contato' : 'E-mail', false),
        if (dono != null) ('phone', 'Telefone', false),
        ('password', 'Senha', false),
      ],
    );
    if (dados == null || !mounted) return;
    await _executar(() async {
      final api = LojaApi(_endereco.text);
      final resposta = await api.chamar(dono == null ? 'login' : 'register', {
        ...dados,
        if (dono != null) 'owner': dono,
      });
      _api = api..token = resposta['token'] as String;
      await _atualizar();
    });
  }

  Future<void> _participar(bool porCodigo) async {
    final campo = porCodigo ? 'code' : 'contact';
    final dados = await _formulario(
      context,
      porCodigo ? 'Entrar com código' : 'Solicitar acesso',
      [
        (
          campo,
          porCodigo ? 'Código da loja' : 'E-mail cadastrado pelo dono',
          false,
        ),
      ],
    );
    if (dados == null || !mounted) return;
    await _executar(() async {
      final resposta = await _api!.chamar('join', dados);
      await _atualizar();
      if (!mounted || porCodigo) return;
      _mensagem(
        context,
        resposta['emailed'] == true
            ? 'Solicitação registrada e enviada por e-mail.'
            : 'Solicitação está no Stokio. O envio por e-mail não foi confirmado.',
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Loja compartilhada'),
      actions: [
        if (_api?.token != null)
          IconButton(
            tooltip: 'Sair',
            onPressed: _ocupado
                ? null
                : () => _executar(() async {
                    await _api!.chamar('logout', {});
                    _api = null;
                    _lojas = [];
                  }),
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_ocupado) const LinearProgressIndicator(),
        if (_api?.token == null) ...[
          if (const String.fromEnvironment('STOKIO_API_URL').isEmpty)
            TextField(
              controller: _endereco,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                hintText: 'https://estoque.sualoja.com.br',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _ocupado ? null : () => _autenticar(),
            child: const Text('Entrar'),
          ),
          TextButton(
            onPressed: _ocupado ? null : () => _autenticar(dono: true),
            child: const Text('Cadastrar meu mercado'),
          ),
          TextButton(
            onPressed: _ocupado ? null : () => _autenticar(dono: false),
            child: const Text('Cadastrar como funcionário'),
          ),
        ] else ...[
          for (final loja in _lojas)
            ListTile(
              title: Text(loja['name'] as String),
              subtitle: Text(loja['role'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final api = _api!;
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _InventarioLoja(api: api, loja: loja),
                  ),
                );
                if (mounted) await _executar(_atualizar);
              },
            ),
          OutlinedButton(
            onPressed: _ocupado ? null : () => _participar(true),
            child: const Text('Entrar com código'),
          ),
          TextButton(
            onPressed: _ocupado ? null : () => _participar(false),
            child: const Text('Solicitar acesso por e-mail'),
          ),
          TextButton(
            onPressed: _ocupado ? null : () => _executar(_atualizar),
            child: const Text('Atualizar minhas lojas'),
          ),
        ],
      ],
    ),
  );
}

class _InventarioLoja extends StatefulWidget {
  const _InventarioLoja({required this.api, required this.loja});
  final LojaApi api;
  final Map<String, dynamic> loja;
  @override
  State<_InventarioLoja> createState() => _InventarioLojaState();
}

class _InventarioLojaState extends State<_InventarioLoja> {
  List<Map<String, dynamic>> _produtos = [], _corredores = [];
  String _busca = '';
  String? _categoria, _corredor;
  bool _carregando = false;
  bool _somenteVencimentos = false;
  String? _erroAtual;
  bool get _gestor => widget.loja['role'] != 'funcionario';
  String get _rota => 'stores/${widget.loja['id']}';

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erroAtual = null;
    });
    try {
      final resposta = await widget.api.chamar('$_rota/inventory');
      if (!mounted) return;
      setState(() {
        _produtos = registros(resposta, 'products');
        _corredores = registros(resposta, 'aisles');
      });
    } catch (erro) {
      if (mounted) setState(() => _erroAtual = _erro(erro));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar(String destino, Map<String, Object?> dados) async {
    await widget.api.chamar('$_rota/$destino', dados);
    if (mounted) await _atualizar();
  }

  Future<void> _produto({
    Map<String, dynamic>? atual,
    bool escanear = false,
    String? codigoCatalogo,
  }) async {
    Map<String, dynamic>? sugestao;
    final code =
        codigoCatalogo ??
        (escanear ? await lerCodigo(context) : atual?['barcode'] as String?);
    if (!mounted) return;
    if (escanear && code == null) return;
    if (code != null && atual == null) {
      for (final produto in _produtos) {
        if (produto['barcode'] == code) {
          await _produto(atual: produto);
          return;
        }
      }
    }
    if (atual == null && code != null) {
      try {
        sugestao = await widget.api.chamar(
          'catalog/${Uri.encodeComponent(code)}',
        );
      } catch (erro) {
        if (!mounted) return;
        _mensagem(context, '${_erro(erro)} Você pode preencher manualmente.');
      }
    }
    if (!mounted) return;
    final dados = await _formulario(
      context,
      atual == null ? 'Novo produto' : 'Editar produto',
      [
        ('name', 'Nome do produto', false),
        ('category', 'Categoria', false),
        ('barcode', 'Código de barras', true),
        ('quantity', 'Quantidade', false),
        ('expiration', 'Validade (AAAA-MM-DD)', true),
      ],
      inicial: {
        ...?sugestao,
        ...?atual,
        if (code != null) 'barcode': code,
        if (atual == null) 'quantity': '0',
      },
      opcoes: {
        'category': {
          for (final c in {
            ...categoriasMercado,
            ..._produtos.map((p) => p['category'] as String),
          })
            c: c,
        },
      },
      extra: (
        'aisle',
        'Corredor',
        {for (final a in _corredores) a['id'] as String: a['name'] as String},
      ),
      rodape: sugestao == null
          ? null
          : 'Sugestão do catálogo Open Food Facts. Confira antes de salvar.',
    );
    if (dados == null || !mounted) return;
    await _acao(
      context,
      () => _salvar('products', {
        ...dados,
        'quantity': int.tryParse(dados['quantity'] ?? ''),
        if (atual != null) ...{
          'id': atual['id'],
          'revision': atual['revision'],
        },
      }),
    );
  }

  Future<void> _catalogo() async {
    final itens = registros(await widget.api.chamar('catalog'), 'products');
    if (!mounted) return;
    final codigo = await showDialog<String>(
      context: context,
      builder: (context) {
        var busca = '';
        return StatefulBuilder(
          builder: (context, atualizar) => AlertDialog(
            title: const Text('Catálogo de produtos'),
            content: SizedBox(
              width: 450,
              height: 340,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar no catálogo por nome ou código',
                    ),
                    onChanged: (v) =>
                        atualizar(() => busca = v.trim().toLowerCase()),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in itens)
                          if ('${item['name']} ${item['code']}'
                              .toLowerCase()
                              .contains(busca))
                            ListTile(
                              title: Text(item['name'] as String),
                              subtitle: Text(
                                '${item['category']} · ${item['code']}',
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                item['code'] as String,
                              ),
                            ),
                      ],
                    ),
                  ),
                  const Text('Dados de Open Food Facts · ODbL'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
    );
    if (codigo != null && mounted) await _produto(codigoCatalogo: codigo);
  }

  Future<void> _importarLocal() async {
    final produtos = estoque.produtos.toList();
    if (produtos.isEmpty) {
      _mensagem(context, 'O estoque local está vazio.');
      return;
    }
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copiar estoque deste aparelho?'),
        content: Text(
          'Serão copiados ${produtos.length} produtos, quantidades, categorias, códigos e a validade mais próxima. O cadastro local e o histórico continuam no aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copiar produtos'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    var adicionados = 0;
    for (var i = 0; i < produtos.length; i += 200) {
      final resposta = await widget.api.chamar('$_rota/import', {
        'products': [
          for (final produto in produtos.skip(i).take(200))
            {
              'source': produto.id,
              'name': produto.nome,
              'category': categoriaExibida(produto.nome, produto.categoria),
              'quantity': produto.quantidade,
              'barcode': produto.codigoBarras,
              'expiration': produto.validade
                  ?.toIso8601String()
                  .split('T')
                  .first,
            },
        ],
      });
      adicionados += resposta['inserted'] as int;
    }
    if (!mounted) return;
    _mensagem(
      context,
      '$adicionados produtos copiados. Os já importados foram preservados.',
    );
    await _atualizar();
  }

  Future<void> _corredoresTela() async {
    final equipe = await widget.api.chamar('$_rota/team');
    if (!mounted) return;
    final pessoas = {
      for (final p in registros(equipe, 'members'))
        p['id'] as String: p['name'] as String,
    };
    final opcoes = [
      'Adicionar corredor',
      ..._corredores.map((c) => c['name'] as String),
    ];
    final indice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Corredores'),
        children: [
          for (var i = 0; i < opcoes.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(opcoes[i]),
            ),
        ],
      ),
    );
    if (indice == null || !mounted) return;
    final atual = indice == 0 ? null : _corredores[indice - 1];
    final dados = await _formulario(
      context,
      opcoes[indice],
      [('name', 'Nome do corredor', false)],
      inicial: atual ?? {},
      extra: ('responsible', 'Responsável', pessoas),
    );
    if (dados == null || !mounted) return;
    await _salvar('aisles', {...dados, if (atual != null) 'id': atual['id']});
  }

  @override
  Widget build(BuildContext context) {
    String categoria(Map<String, dynamic> p) =>
        categoriaExibida(p['name'] as String, p['category'] as String);
    final categorias = _produtos.map(categoria).toSet().toList()..sort();
    bool pertoDeVencer(Map<String, dynamic> p) {
      final data = DateTime.tryParse(p['expiration']?.toString() ?? '');
      return data != null &&
          (p['quantity'] as int) > 0 &&
          diasDesde(data) >= -7;
    }

    final produtos = _produtos.where(
      (p) =>
          (!_somenteVencimentos || pertoDeVencer(p)) &&
          (_categoria == null || categoria(p) == _categoria) &&
          (_corredor == null || p['aisle'] == _corredor) &&
          '${p['name']} ${p['barcode'] ?? ''}'.toLowerCase().contains(_busca),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loja['name'] as String),
        actions: [
          IconButton(
            tooltip: 'Atualizar estoque',
            onPressed: _atualizar,
            icon: const Icon(Icons.refresh),
          ),
          if (_gestor)
            IconButton(
              tooltip: 'Cadastrar pelo código de barras',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _produto(escanear: true),
            ),
          if (_gestor)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'team') {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _Equipe(
                        api: widget.api,
                        rota: _rota,
                        dono: widget.loja['role'] == 'dono',
                      ),
                    ),
                  );
                } else if (value == 'catalog') {
                  await _acao(context, _catalogo);
                } else if (value == 'import') {
                  await _acao(context, _importarLocal);
                } else {
                  await _acao(context, _corredoresTela);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'team',
                  child: Text('Equipe e código da loja'),
                ),
                PopupMenuItem(
                  value: 'aisles',
                  child: Text('Gerenciar corredores'),
                ),
                PopupMenuItem(
                  value: 'catalog',
                  child: Text('Cadastrar pelo catálogo'),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Text('Copiar estoque local'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: !_gestor
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _produto(),
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (_carregando) const LinearProgressIndicator(),
          if (_erroAtual != null) Text(_erroAtual!),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar nome ou código',
            ),
            onChanged: (v) => setState(() => _busca = v.trim().toLowerCase()),
          ),
          DropdownButton<String>(
            isExpanded: true,
            value: categorias.contains(_categoria) ? _categoria : '',
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todas as categorias'),
              ),
              for (final c in categorias)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _categoria = v == '' ? null : v),
          ),
          DropdownButton<String>(
            isExpanded: true,
            value: _corredor ?? '',
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todos os corredores'),
              ),
              for (final a in _corredores)
                DropdownMenuItem(
                  value: a['id'] as String,
                  child: Text(
                    '${a['name']}${a['responsible_name'] == null ? '' : ' · ${a['responsible_name']}'}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _corredor = v == '' ? null : v),
          ),
          FilterChip(
            label: const Text('Vencidos ou vencendo em 7 dias'),
            selected: _somenteVencimentos,
            onSelected: (valor) => setState(() => _somenteVencimentos = valor),
          ),
          if (produtos.isEmpty && !_carregando)
            const ListTile(title: Text('Nenhum produto encontrado.')),
          for (final p in produtos)
            ListTile(
              title: Text(p['name'] as String),
              subtitle: Text(
                [
                  categoria(p),
                  if (p['aisle_name'] != null) p['aisle_name'],
                  p['expiration'] == null
                      ? 'Sem validade informada'
                      : 'Validade ${p['expiration']}',
                ].join(' · '),
              ),
              trailing: Text('${p['quantity']}'),
              onTap: !_gestor ? null : () => _produto(atual: p),
            ),
        ],
      ),
    );
  }
}

class _Equipe extends StatefulWidget {
  const _Equipe({required this.api, required this.rota, required this.dono});
  final LojaApi api;
  final String rota;
  final bool dono;
  @override
  State<_Equipe> createState() => _EquipeState();
}

class _EquipeState extends State<_Equipe> {
  late Future<Map<String, dynamic>> _dados = widget.api.chamar(
    '${widget.rota}/team',
  );
  void _atualizar() =>
      setState(() => _dados = widget.api.chamar('${widget.rota}/team'));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Equipe'),
      actions: [
        IconButton(
          onPressed: _atualizar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar equipe',
        ),
      ],
    ),
    body: FutureBuilder(
      future: _dados,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text(_erro(snapshot.error!)));
        final data = snapshot.data;
        if (data == null)
          return const Center(child: CircularProgressIndicator());
        final membros = registros(data, 'members');
        final pedidos = registros(data, 'requests');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Código da loja'),
              subtitle: SelectableText(data['invite'] as String),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar código',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: data['invite'] as String),
                  );
                  if (context.mounted) _mensagem(context, 'Código copiado.');
                },
              ),
            ),
            const ListTile(title: Text('Solicitações de acesso')),
            if (pedidos.isEmpty)
              const ListTile(subtitle: Text('Nenhuma solicitação pendente.')),
            for (final p in pedidos) _pessoa(p, pendente: true),
            const ListTile(title: Text('Pessoas da loja')),
            for (final p in membros)
              _pessoa(
                p,
                bloqueado:
                    p['id'] == data['founder'] ||
                    (!widget.dono && p['role'] == 'dono'),
              ),
          ],
        );
      },
    ),
  );

  Widget _pessoa(
    Map<String, dynamic> p, {
    bool pendente = false,
    bool bloqueado = false,
  }) => ListTile(
    title: Text(p['name'] as String),
    subtitle: Text(
      '${p['email']} · ${p['phone']}${pendente ? '' : ' · ${p['role']}'}',
    ),
    trailing: bloqueado
        ? null
        : PopupMenuButton<String>(
            tooltip: pendente ? 'Revisar solicitação' : 'Alterar cargo',
            onSelected: (cargo) => _acao(context, () async {
              await widget.api.chamar('${widget.rota}/role', {
                'user': p['id'],
                'role': cargo,
              });
              if (mounted) _atualizar();
            }),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'funcionario',
                child: Text('Funcionário'),
              ),
              const PopupMenuItem(value: 'gerente', child: Text('Gerente')),
              if (widget.dono)
                const PopupMenuItem(value: 'dono', child: Text('Dono')),
              if (pendente)
                const PopupMenuItem(value: 'recusar', child: Text('Recusar')),
            ],
          ),
  );
}

String _erro(Object erro) {
  if (erro is LojaErro) return erro.mensagem;
  if (erro is FormatException && erro.message.startsWith('Informe'))
    return erro.message;
  return 'Não foi possível conectar ao servidor. Confira o endereço e tente novamente.';
}

void _mensagem(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

Future<void> _acao(BuildContext context, Future<void> Function() acao) async {
  try {
    await acao();
  } catch (erro) {
    if (context.mounted) _mensagem(context, _erro(erro));
  }
}

Future<Map<String, String>?> _formulario(
  BuildContext context,
  String titulo,
  List<(String, String, bool)> campos, {
  Map<String, dynamic> inicial = const {},
  Map<String, Map<String, String>> opcoes = const {},
  (String, String, Map<String, String>)? extra,
  String? rodape,
}) async {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _Formulario(
      titulo: titulo,
      campos: campos,
      inicial: inicial,
      opcoes: opcoes,
      extra: extra,
      rodape: rodape,
    ),
  );
}

class _Formulario extends StatefulWidget {
  const _Formulario({
    required this.titulo,
    required this.campos,
    required this.inicial,
    required this.opcoes,
    this.extra,
    this.rodape,
  });
  final String titulo;
  final List<(String, String, bool)> campos;
  final Map<String, dynamic> inicial;
  final Map<String, Map<String, String>> opcoes;
  final (String, String, Map<String, String>)? extra;
  final String? rodape;
  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _form = GlobalKey<FormState>();
  late final _dados = {
    for (final (chave, _, _) in widget.campos)
      chave: widget.inicial[chave]?.toString() ?? '',
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (chave, rotulo, opcional) in widget.campos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: widget.opcoes[chave] != null
                  ? _seletor(chave, rotulo, widget.opcoes[chave]!, false)
                  : TextFormField(
                      initialValue: _dados[chave],
                      obscureText: chave == 'password',
                      keyboardType: switch (chave) {
                        'email' || 'contact' => TextInputType.emailAddress,
                        'phone' => TextInputType.phone,
                        'quantity' => TextInputType.number,
                        _ => TextInputType.text,
                      },
                      decoration: InputDecoration(
                        labelText: opcional ? '$rotulo (opcional)' : rotulo,
                      ),
                      validator: (v) =>
                          !(opcional || (v ?? '').trim().isNotEmpty)
                          ? 'Preencha este campo.'
                          : null,
                      onSaved: (v) => _dados[chave] = chave == 'password'
                          ? v ?? ''
                          : (v ?? '').trim(),
                    ),
            ),
          if (widget.extra != null)
            _seletor(
              widget.extra!.$1,
              widget.extra!.$2,
              widget.extra!.$3,
              true,
            ),
          if (widget.rodape != null) Text(widget.rodape!),
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
          if (!_form.currentState!.validate()) return;
          _form.currentState!.save();
          Navigator.pop(context, _dados);
        },
        child: const Text('Confirmar'),
      ),
    ],
  );

  Widget _seletor(
    String chave,
    String rotulo,
    Map<String, String> opcoes,
    bool opcional,
  ) {
    final valor = widget.inicial[chave]?.toString();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: opcoes.containsKey(valor) ? valor : null,
      decoration: InputDecoration(labelText: rotulo),
      items: [
        if (opcional)
          const DropdownMenuItem(value: '', child: Text('Sem vínculo')),
        for (final e in opcoes.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      validator: (v) => !opcional && v == null ? 'Selecione uma opção.' : null,
      onChanged: (_) {},
      onSaved: (v) => _dados[chave] = v ?? '',
    );
  }
}
