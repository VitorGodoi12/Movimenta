import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stokio/models/fornecedor.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/whatsapp.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/estado_vazio.dart';

/// Lista de reposição agrupada por fornecedor.
/// A quantidade sugerida leva o produto a 2x o estoque mínimo.
class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  final Set<String> _comprados = {};

  List<ItemCompra> _pendentes(List<ItemCompra> itens) =>
      itens.where((i) => !_comprados.contains(i.produto.id)).toList();

  String _linhas(List<ItemCompra> itens) => itens
      .map((i) => '- ${i.produto.nome}: ${i.sugerido} ${i.produto.unidade}')
      .join('\n');

  String _textoGeral(List<ItemCompra> itens) {
    final nome = perfil.cliente?.estabelecimento ?? 'Meu estoque';
    return 'Lista de compras - $nome\n\n${_linhas(_pendentes(itens))}';
  }

  Future<void> _pedir(Fornecedor f, List<ItemCompra> itens) async {
    final pend = _pendentes(itens);
    if (pend.isEmpty) {
      avisar(context, 'Todos os itens deste fornecedor já foram marcados.');
      return;
    }
    final texto = 'Olá! Gostaria de fazer um pedido:\n${_linhas(pend)}\nObrigado!';
    final ok = await abrirWhatsapp(f.telefone, texto);
    if (!ok && mounted) avisar(context, 'Não consegui abrir o WhatsApp.');
  }

  Fornecedor? _fornecedor(String id) {
    for (final f in estoque.fornecedores) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final itens = estoque.listaCompras;
        final pendentes = _pendentes(itens).length;

        // Agrupa por fornecedor; quem não tem fornecedor fica por último.
        final grupos = <String, List<ItemCompra>>{};
        for (final i in itens) {
          final chave =
              _fornecedor(i.produto.fornecedorId ?? '') == null
                  ? ''
                  : i.produto.fornecedorId!;
          grupos.putIfAbsent(chave, () => []).add(i);
        }
        final chaves = grupos.keys.toList()
          ..sort((a, b) {
            if (a.isEmpty) return 1;
            if (b.isEmpty) return -1;
            return _fornecedor(a)!
                .nome
                .toLowerCase()
                .compareTo(_fornecedor(b)!.nome.toLowerCase());
          });

        final children = <Widget>[];
        for (final chave in chaves) {
          final f = chave.isEmpty ? null : _fornecedor(chave);
          final doGrupo = grupos[chave]!;
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      f?.nome ?? 'Sem fornecedor',
                      style:
                          t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (f != null && f.telefone.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _pedir(f, doGrupo),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Pedir no WhatsApp'),
                    ),
                ],
              ),
            ),
          );
          for (final item in doGrupo) {
            final p = item.produto;
            final marcado = _comprados.contains(p.id);
            children.add(
              CheckboxListTile(
                value: marcado,
                activeColor: AppCores.preto,
                checkColor: AppCores.branco,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _comprados.add(p.id);
                  } else {
                    _comprados.remove(p.id);
                  }
                }),
                title: Text(
                  p.nome,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration:
                        marcado ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text('Tem ${p.quantidade}, mínimo ${p.minimo}'),
                secondary: Text(
                  '+${item.sugerido} ${p.unidade}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Lista de compras')),
          body: itens.isEmpty
              ? const EstadoVazio(
                  icone: Icons.shopping_cart_outlined,
                  titulo: 'Nada para repor agora',
                  texto: 'Quando um produto chegar ao mínimo, ele aparece aqui.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'A quantidade sugerida leva cada produto a 2 vezes o estoque mínimo. Marque o que já comprou.',
                          style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: children,
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: FilledButton.icon(
                          onPressed: pendentes == 0
                              ? null
                              : () => Share.share(_textoGeral(itens)),
                          icon: const Icon(Icons.share_outlined),
                          label: Text('Compartilhar lista ($pendentes)'),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
