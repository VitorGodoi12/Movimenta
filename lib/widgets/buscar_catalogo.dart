import 'package:flutter/material.dart';
import 'package:stokio/services/open_food_facts_web.dart'
    if (dart.library.io) 'package:stokio/services/open_food_facts.dart';
import 'package:stokio/services/sugestao_catalogo.dart';

const buscaCatalogoDisponivel = OpenFoodFacts.disponivel;

Future<SugestaoCatalogo?> buscarNoCatalogo(BuildContext context, String nome) {
  return showModalBottomSheet<SugestaoCatalogo>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ResultadosCatalogo(nome: nome),
  );
}

class _ResultadosCatalogo extends StatefulWidget {
  const _ResultadosCatalogo({required this.nome});

  final String nome;

  @override
  State<_ResultadosCatalogo> createState() => _ResultadosCatalogoState();
}

class _ResultadosCatalogoState extends State<_ResultadosCatalogo> {
  late final _busca = OpenFoodFacts.buscarNome(widget.nome);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SugestaoCatalogo>>(
      future: _busca,
      builder: (context, estado) {
        final sugestoes = estado.data ?? const <SugestaoCatalogo>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              'Sugestões para ' + widget.nome,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Open Food Facts · confira a embalagem e o código.'),
            const SizedBox(height: 12),
            if (estado.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (estado.hasError)
              const Text(
                'Catálogo indisponível. Você pode continuar manualmente.',
              )
            else if (sugestoes.isEmpty)
              const Text('Nenhuma sugestão. Você pode manter o nome informado.')
            else
              for (final sugestao in sugestoes)
                ListTile(
                  title: Text(sugestao.nome),
                  subtitle: Text(sugestao.codigo),
                  trailing: const Icon(Icons.add),
                  onTap: () => Navigator.pop(context, sugestao),
                ),
          ],
        );
      },
    );
  }
}
