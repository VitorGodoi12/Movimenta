import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/estoque/importar_estoque_screen.dart';
import 'package:stokio/screens/estoque/produto_detalhe_screen.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/fluxo_scanner.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/categorias_mercado.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/widgets/estado_vazio.dart';
import 'package:stokio/widgets/produto_tile.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/cartao_painel.dart';

enum FiltroEstoque { todos, acabando, zerados, vencendo, emFalta }

enum _Ordem { nome, menorEstoque, validade }

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key, this.filtroInicial = FiltroEstoque.todos});

  final FiltroEstoque filtroInicial;

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  String _busca = '';
  late FiltroEstoque _filtro = widget.filtroInicial;
  String? _categoria;
  final _recolhidas = <String>{};

  String _nomeCategoria(Produto produto) =>
      categoriaExibida(produto.nome, produto.categoria);
  _Ordem _ordem = _Ordem.nome;

  String _rotuloFiltro(FiltroEstoque f) => switch (f) {
    FiltroEstoque.todos => 'Todos',
    FiltroEstoque.acabando => 'Acabando',
    FiltroEstoque.zerados => 'Zerados',
    FiltroEstoque.vencendo => 'Vencendo',
    FiltroEstoque.emFalta => 'Em falta',
  };

  String _rotuloOrdem(_Ordem o) => switch (o) {
    _Ordem.nome => 'Nome (A a Z)',
    _Ordem.menorEstoque => 'Menor estoque',
    _Ordem.validade => 'Validade mais próxima',
  };

  bool _venceLogo(Produto p) {
    if (p.quantidade <= 0) return false;
    final s = p.situacaoValidade(perfil.diasAvisoValidade);
    return s == SituacaoValidade.vencendo || s == SituacaoValidade.vencido;
  }

  List<Produto> _filtrar(List<Produto> todos) {
    final b = _busca.trim().toLowerCase();
    final categoria = todos.any((p) => _nomeCategoria(p) == _categoria)
        ? _categoria
        : null;
    final lista = todos.where((p) {
      final okBusca =
          b.isEmpty ||
          p.nome.toLowerCase().contains(b) ||
          p.categoria.toLowerCase().contains(b) ||
          (p.codigoBarras ?? '').contains(b) ||
          (p.local ?? '').toLowerCase().contains(b);
      final okFiltro = switch (_filtro) {
        FiltroEstoque.todos => true,
        FiltroEstoque.acabando => p.situacao == SituacaoEstoque.baixo,
        FiltroEstoque.zerados => p.situacao == SituacaoEstoque.zerado,
        FiltroEstoque.vencendo => _venceLogo(p),
        FiltroEstoque.emFalta => p.situacao != SituacaoEstoque.normal,
      };
      return okBusca &&
          okFiltro &&
          (categoria == null || _nomeCategoria(p) == categoria);
    }).toList();

    switch (_ordem) {
      case _Ordem.nome:
        lista.sort(
          (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
        );
      case _Ordem.menorEstoque:
        lista.sort((a, b) => a.quantidade.compareTo(b.quantidade));
      case _Ordem.validade:
        lista.sort((a, b) {
          if (a.validade == null && b.validade == null) return 0;
          if (a.validade == null) return 1;
          if (b.validade == null) return -1;
          return a.validade!.compareTo(b.validade!);
        });
    }
    return lista;
  }

  Future<void> _importar() async {
    final total = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ImportarEstoqueScreen()),
    );
    if (total != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$total produtos importados.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([estoque, perfil]),
      builder: (context, _) {
        final lista = _filtrar(estoque.produtos);
        final grupos = <String, List<Produto>>{};
        for (final produto in lista) {
          final categoria = _nomeCategoria(produto);
          (grupos[categoria.isEmpty ? 'Outros' : categoria] ??= []).add(
            produto,
          );
        }
        final categorias = grupos.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final todasCategorias =
            estoque.produtos.map(_nomeCategoria).toSet().toList()..sort();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Estoque'),
            actions: [
              IconButton(
                tooltip: 'Importar lista de estoque',
                onPressed: _importar,
                icon: const Icon(Icons.playlist_add),
              ),
              PopupMenuButton<_Ordem>(
                tooltip: 'Ordenar',
                icon: const Icon(Icons.sort),
                initialValue: _ordem,
                onSelected: (o) => setState(() => _ordem = o),
                itemBuilder: (_) => [
                  for (final o in _Ordem.values)
                    PopupMenuItem(value: o, child: Text(_rotuloOrdem(o))),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProdutoFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Novo produto'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar produto ou código',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Escanear código de barras',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () => escanearEAbrir(context),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final f in {
                      FiltroEstoque.todos,
                      FiltroEstoque.vencendo,
                      FiltroEstoque.emFalta,
                      if (_filtro == FiltroEstoque.acabando ||
                          _filtro == FiltroEstoque.zerados)
                        _filtro,
                    })
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selectedColor: AppCores.preto,
                          labelStyle: TextStyle(
                            color: _filtro == f ? Colors.white : AppCores.preto,
                            fontWeight: FontWeight.w700,
                          ),
                          label: Text(switch (f) {
                            FiltroEstoque.todos => 'Todos ${estoque.total}',
                            FiltroEstoque.vencendo =>
                              'Vencendo ${estoque.vencendo.length + estoque.vencidos.length}',
                            FiltroEstoque.emFalta =>
                              'Em falta ${estoque.baixos.length + estoque.zerados.length}',
                            _ => _rotuloFiltro(f),
                          }),
                          selected: _filtro == f,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                      ),
                  ],
                ),
              ),
              if (todasCategorias.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: todasCategorias.contains(_categoria)
                        ? _categoria
                        : '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todas as categorias'),
                      ),
                      for (final categoria in todasCategorias)
                        DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _categoria = v == '' ? null : v),
                  ),
                ),
              Expanded(
                child: estoque.total == 0
                    ? const EstadoVazio(
                        icone: Icons.inventory_2_outlined,
                        titulo: 'Nenhum produto ainda',
                        texto: 'Cadastre um produto ou importe uma lista de estoque.',
                      )
                    : lista.isEmpty
                    ? const EstadoVazio(
                        icone: Icons.search_off,
                        titulo: 'Nenhum produto encontrado',
                        texto: 'Mude a busca ou o filtro.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
                        itemCount: categorias.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final categoria = categorias[i];
                          final aberto =
                              !_recolhidas.contains(categoria) ||
                              _busca.isNotEmpty;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  categoria,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppCores.cinza,
                                  ),
                                ),
                                trailing: Icon(
                                  aberto
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onTap: () => setState(() {
                                  if (!_recolhidas.remove(categoria))
                                    _recolhidas.add(categoria);
                                }),
                              ),
                              if (aberto)
                                CartaoPainel(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      for (final (indice, produto)
                                          in grupos[categoria]!.indexed) ...[
                                        if (indice > 0)
                                          const Divider(
                                            height: 1,
                                            indent: 12,
                                            endIndent: 12,
                                          ),
                                        ProdutoTile(
                                          produto: produto,
                                          compacto: true,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProdutoDetalheScreen(
                                                    produto: produto,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
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
}
