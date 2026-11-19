import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/theme/app_theme.dart';
import 'package:movimenta/widgets/estado_vazio.dart';

/// Lista de reposição: tudo que está no mínimo ou abaixo.
/// A quantidade sugerida leva o produto a 2x o estoque mínimo.
class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  final Set<String> _comprados = {};

  String _montarTexto(List<ItemCompra> itens) {
    final nome = perfil.cliente?.estabelecimento ?? 'Meu estoque';
    final pendentes =
        itens.where((i) => !_comprados.contains(i.produto.id)).toList();
    final linhas = [
      'Lista de compras - $nome',
      '',
      for (final i in pendentes)
        '- ${i.produto.nome}: ${i.sugerido} ${i.produto.unidade}',
    ];
    return linhas.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final itens = estoque.listaCompras;
        final pendentes =
            itens.where((i) => !_comprados.contains(i.produto.id)).length;

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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'A quantidade sugerida leva cada produto a 2 vezes o estoque mínimo. Marque o que já comprou.',
                          style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: itens.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppCores.linha),
                        itemBuilder: (context, i) {
                          final item = itens[i];
                          final p = item.produto;
                          final marcado = _comprados.contains(p.id);
                          return CheckboxListTile(
                            value: marcado,
                            activeColor: AppCores.preto,
                            checkColor: AppCores.branco,
                            controlAffinity: ListTileControlAffinity.leading,
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
                                decoration: marcado
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              'Tem ${p.quantidade}, mínimo ${p.minimo}',
                            ),
                            secondary: Text(
                              '+${item.sugerido} ${p.unidade}',
                              style: t.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: FilledButton.icon(
                          onPressed: pendentes == 0
                              ? null
                              : () => Share.share(_montarTexto(itens)),
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
