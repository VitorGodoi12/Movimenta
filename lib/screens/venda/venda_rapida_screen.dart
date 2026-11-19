import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/estado_vazio.dart';

class _ItemCarrinho {
  _ItemCarrinho(this.produto, this.quantidade);

  final Produto produto;
  int quantidade;
}

/// Venda de balcão: escaneie ou busque os produtos, confira o total
/// e finalize. Cada item vira uma saída com motivo "Venda".
class VendaRapidaScreen extends StatefulWidget {
  const VendaRapidaScreen({super.key});

  @override
  State<VendaRapidaScreen> createState() => _VendaRapidaScreenState();
}

class _VendaRapidaScreenState extends State<VendaRapidaScreen> {
  final List<_ItemCarrinho> _itens = [];

  double get _total =>
      _itens.fold(0.0, (soma, i) => soma + i.quantidade * i.produto.preco);

  int get _unidades => _itens.fold(0, (soma, i) => soma + i.quantidade);

  /// Devolve (deu certo?, mensagem).
  (bool, String) _adicionar(Produto p) {
    if (p.quantidade <= 0) return (false, '${p.nome}: sem estoque');
    final i = _itens.indexWhere((x) => x.produto.id == p.id);
    if (i >= 0) {
      if (_itens[i].quantidade >= p.quantidade) {
        return (false, '${p.nome}: só há ${p.quantidade} ${p.unidade}');
      }
      setState(() => _itens[i].quantidade += 1);
      return (true, '${p.nome}: ${_itens[i].quantidade} ${p.unidade}');
    }
    setState(() => _itens.add(_ItemCarrinho(p, 1)));
    return (true, '${p.nome} adicionado');
  }

  void _alterar(_ItemCarrinho item, int passo) {
    final novo = item.quantidade + passo;
    setState(() {
      if (novo <= 0) {
        _itens.remove(item);
      } else if (novo <= item.produto.quantidade) {
        item.quantidade = novo;
      }
    });
  }

  Future<void> _escanear() {
    return lerEmSequencia(
      context,
      dica: 'Escaneie os produtos da venda',
      aoLer: (codigo) {
        final p = estoque.porCodigo(codigo);
        if (p == null) return 'Código $codigo não cadastrado';
        return _adicionar(p).$2;
      },
    );
  }

  Future<void> _buscar() async {
    final p = await showModalBottomSheet<Produto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppCores.branco,
      builder: (_) => const _SeletorProduto(),
    );
    if (p == null || !mounted) return;
    final (ok, msg) = _adicionar(p);
    if (!ok) avisar(context, msg);
  }

  void _finalizar() {
    final total = _total;
    final itens = [for (final i in _itens) ItemVenda(i.produto, i.quantidade)];
    final movs = estoque.registrarVenda(itens);
    if (movs.isEmpty) {
      avisar(context, 'Confira as quantidades disponíveis antes de finalizar.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Venda registrada: ${formatarPreco(total)}'),
          action: SnackBarAction(
            label: 'Desfazer',
            textColor: AppCores.roxo,
            onPressed: () => estoque.desfazerVarias(movs),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Venda rápida')),
      body: Column(
        children: [
          Expanded(
            child: _itens.isEmpty
                ? const EstadoVazio(
                    icone: Icons.point_of_sale,
                    titulo: 'Nenhum item na venda',
                    texto:
                        'Escaneie os códigos de barras ou busque os produtos. O estoque só baixa quando você finalizar.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    itemCount: _itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = _itens[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppCores.branco,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppCores.linha),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.produto.nome,
                                    style: t.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatarPreco(item.produto.preco)} cada',
                                    style: t.bodySmall
                                        ?.copyWith(color: AppCores.cinza),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'Tirar um',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _alterar(item, -1),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${item.quantidade}',
                                textAlign: TextAlign.center,
                                style: t.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'Adicionar um',
                              icon: const Icon(Icons.add),
                              onPressed: () => _alterar(item, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppCores.branco,
              border: Border(top: BorderSide(color: AppCores.linha)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$_unidades ${_unidades == 1 ? 'item' : 'itens'}',
                          style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                        ),
                        const Spacer(),
                        Text('Total  ', style: t.bodyMedium),
                        Text(
                          formatarPreco(_total),
                          style: t.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _escanear,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Escanear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _buscar,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _itens.isEmpty ? null : _finalizar,
                      child: const Text('Finalizar venda'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeletorProduto extends StatefulWidget {
  const _SeletorProduto();

  @override
  State<_SeletorProduto> createState() => _SeletorProdutoState();
}

class _SeletorProdutoState extends State<_SeletorProduto> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = _busca.trim().toLowerCase();
    final lista = estoque.produtos
        .where((p) =>
            p.quantidade > 0 &&
            (b.isEmpty ||
                p.nome.toLowerCase().contains(b) ||
                p.categoria.toLowerCase().contains(b)))
        .toList()
      ..sort((a, c) => a.nome.toLowerCase().compareTo(c.nome.toLowerCase()));
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar produto',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const EstadoVazio(
                      icone: Icons.search_off,
                      titulo: 'Nada encontrado',
                      texto: 'Só aparecem produtos com estoque.',
                    )
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (context, i) {
                        final p = lista[i];
                        return ListTile(
                          title: Text(
                            p.nome,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${p.quantidade} ${p.unidade} em estoque',
                            style: t.bodySmall,
                          ),
                          trailing: Text(
                            formatarPreco(p.preco),
                            style: t.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
