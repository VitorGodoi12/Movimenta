import 'package:flutter/material.dart';
import 'package:movimenta/models/produto.dart';
import 'package:movimenta/screens/estoque/importar_estoque_screen.dart';
import 'package:movimenta/screens/estoque/produto_detalhe_screen.dart';
import 'package:movimenta/screens/estoque/produto_form_screen.dart';
import 'package:movimenta/screens/scanner/fluxo_scanner.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/widgets/estado_vazio.dart';
import 'package:movimenta/widgets/produto_tile.dart';

enum _Filtro { todos, acabando, zerados, vencendo }

enum _Ordem { nome, menorEstoque, validade }

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key});

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  String _busca = '';
  _Filtro _filtro = _Filtro.todos;
  _Ordem _ordem = _Ordem.nome;

  String _rotuloFiltro(_Filtro f) => switch (f) {
    _Filtro.todos => 'Todos',
    _Filtro.acabando => 'Acabando',
    _Filtro.zerados => 'Zerados',
    _Filtro.vencendo => 'Vencendo',
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
    final lista = todos.where((p) {
      final okBusca =
          b.isEmpty ||
          p.nome.toLowerCase().contains(b) ||
          p.categoria.toLowerCase().contains(b) ||
          (p.codigoBarras ?? '').contains(b);
      final okFiltro = switch (_filtro) {
        _Filtro.todos => true,
        _Filtro.acabando => p.situacao == SituacaoEstoque.baixo,
        _Filtro.zerados => p.situacao == SituacaoEstoque.zerado,
        _Filtro.vencendo => _venceLogo(p),
      };
      return okBusca && okFiltro;
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
          final categoria = produto.categoria.trim();
          (grupos[categoria.isEmpty ? 'Outros' : categoria] ??= []).add(
            produto,
          );
        }
        final categorias = grupos.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final linhas = [
          for (final categoria in categorias) ...<Object>[
            categoria,
            ...grupos[categoria]!,
          ],
        ];

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
                    hintText: 'Buscar por nome, categoria ou código',
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
                    for (final f in _Filtro.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_rotuloFiltro(f)),
                          selected: _filtro == f,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                      ),
                  ],
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
                        itemCount: linhas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final linha = linhas[i];
                          if (linha is String) {
                            return Semantics(
                              header: true,
                              child: Text(
                                linha,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          }
                          final produto = linha as Produto;
                          return ProdutoTile(
                            produto: produto,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProdutoDetalheScreen(produto: produto),
                              ),
                            ),
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
