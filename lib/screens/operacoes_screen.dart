import 'package:stokio/widgets/cartao_painel.dart';
import 'package:stokio/theme/app_theme.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/screens/scanner/fluxo_scanner.dart';
import 'package:stokio/screens/venda/venda_rapida_screen.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';

class OperacoesScreen extends StatelessWidget {
  const OperacoesScreen({super.key});

  void _abrir(BuildContext context, Widget tela) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final acoes = <(IconData, String, String, VoidCallback)>[
      (
        Icons.qr_code_scanner,
        'Ler código',
        'Buscar ou cadastrar pela embalagem',
        () => escanearEAbrir(context),
      ),
      (
        Icons.add_box_outlined,
        'Cadastrar produto',
        'Estoque, Loja ou os dois',
        () => _abrir(context, const ProdutoFormScreen()),
      ),
      (
        Icons.move_to_inbox_outlined,
        'Registrar entrada',
        'Repor produtos cadastrados',
        () => mostrarMovimentarSheet(context),
      ),
      (
        Icons.outbox_outlined,
        'Registrar saída',
        'Registrar retirada ou perda',
        () => mostrarMovimentarSheet(context, tipo: TipoMovimento.saida),
      ),
      (
        Icons.shopping_cart_outlined,
        'Lista de compras',
        'Montar lista para mercado ou atacado',
        () => _abrir(context, const _ListaAvulsa()),
      ),
      (
        Icons.local_shipping_outlined,
        'Pedidos a fornecedores',
        'Revisar e enviar pedidos',
        () => _abrir(context, const ListaComprasScreen()),
      ),
      (
        Icons.calculate_outlined,
        'Calculadora',
        'Calcular quantidade × preço ou preço unitário',
        () => _abrir(context, const _Calculadora()),
      ),
      (
        Icons.point_of_sale_outlined,
        'Venda rápida',
        'Montar e fechar uma venda',
        () => _abrir(context, const VendaRapidaScreen()),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Operações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Card(
            color: context.cores.primaryContainer,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: CircleAvatar(
                backgroundColor: context.cores.primary,
                foregroundColor: context.cores.onPrimary,
                child: Icon(acoes.first.$1),
              ),
              title: Text(
                acoes.first.$2,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(acoes.first.$3),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: acoes.first.$4,
            ),
          ),
          for (final (secao, indices) in const [
            ('Movimentar', [1, 2, 3]),
            ('Comprar e vender', [4, 5, 7]),
            ('Ferramentas', [6]),
          ]) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(
                secao,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            CartaoPainel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, indice) in indices.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 54, endIndent: 12),
                    ListTile(
                      leading: Icon(
                        acoes[indice].$1,
                        color: context.cores.primary,
                      ),
                      title: Text(acoes[indice].$2),
                      subtitle: Text(acoes[indice].$3),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: acoes[indice].$4,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListaAvulsa extends StatefulWidget {
  const _ListaAvulsa();

  @override
  State<_ListaAvulsa> createState() => _ListaAvulsaState();
}

class _ListaAvulsaState extends State<_ListaAvulsa> {
  static const _chave = 'movimenta_compras_avulsas';
  late final _itens = (jsonDecode(Armazenamento.ler(_chave) ?? '[]') as List)
      .cast<String>()
      .toList();
  final _novo = TextEditingController();

  @override
  void dispose() {
    _novo.dispose();
    super.dispose();
  }

  void _alterar(VoidCallback acao) {
    setState(acao);
    Armazenamento.gravar(_chave, jsonEncode(_itens));
  }

  void _adicionar() {
    final texto = _novo.text.trim();
    if (texto.isEmpty) return;
    _alterar(() => _itens.add(texto));
    _novo.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lista de compras'),
      actions: [
        IconButton(
          tooltip: 'Compartilhar lista',
          onPressed: _itens.isEmpty
              ? null
              : () {
                  Share.share(_itens.map((item) => '• $item').join('\n'));
                },
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _novo,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _adicionar(),
          decoration: InputDecoration(
            labelText: 'Produto e quantidade',
            hintText: 'Ex.: 2 caixas de leite',
            suffixIcon: IconButton(
              tooltip: 'Adicionar item',
              onPressed: _adicionar,
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        for (final (indice, item) in _itens.indexed)
          ListTile(
            title: Text(item),
            trailing: IconButton(
              tooltip: 'Retirar item',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _alterar(() => _itens.removeAt(indice)),
            ),
          ),
      ],
    ),
  );
}

class _Calculadora extends StatefulWidget {
  const _Calculadora();

  @override
  State<_Calculadora> createState() => _CalculadoraState();
}

class _CalculadoraState extends State<_Calculadora> {
  double _quantidade = 0;
  double _preco = 0;
  bool _unitario = false;

  double _numero(String texto) {
    final numero = double.tryParse(texto.trim().replaceAll(',', '.'));
    return numero != null && numero.isFinite && numero > 0 ? numero : 0;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calculadora')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Calcular preço por unidade'),
          value: _unitario,
          onChanged: (valor) => setState(() => _unitario = valor),
        ),
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantidade'),
          onChanged: (texto) => setState(() => _quantidade = _numero(texto)),
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _unitario ? 'Preço total' : 'Preço unitário',
          ),
          onChanged: (texto) => setState(() => _preco = _numero(texto)),
        ),
        const SizedBox(height: 20),
        Text(
          _quantidade == 0
              ? 'Informe a quantidade'
              : formatarPreco(
                  _unitario ? _preco / _quantidade : _preco * _quantidade,
                ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    ),
  );
}
