import 'package:stokio/utils/codigo_produto.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:flutter/services.dart';
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
  const VendaRapidaScreen({
    super.key,
    this.incorporada = false,
    this.ativa = true,
  });

  final bool incorporada;
  final bool ativa;

  @override
  State<VendaRapidaScreen> createState() => _VendaRapidaScreenState();
}

class _VendaRapidaScreenState extends State<VendaRapidaScreen> {
  final List<_ItemCarrinho> _itens = [];
  bool _camera = false;
  String? _pagamento;
  int _sessaoCamera = 0;
  String? _ultimoCodigo;
  String? _leitura;
  Timer? _limparLeitura;

  @override
  void dispose() {
    _limparLeitura?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VendaRapidaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ativa) {
      _camera = false;
      _ultimoCodigo = null;
    }
  }

  double get _total =>
      _itens.fold(0.0, (soma, i) => soma + i.quantidade * i.produto.preco);

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

  void _escanear() {
    setState(() {
      _camera = !_camera;
      _ultimoCodigo = null;
      _leitura = null;
    });
  }

  void _detectar(BarcodeCapture captura) {
    if (!widget.ativa || !_camera || ModalRoute.of(context)?.isCurrent != true)
      return;
    for (final barcode in captura.barcodes) {
      final codigo = codigoDeProduto(barcode.rawValue);
      if (codigo == null || codigo.isEmpty || codigo == _ultimoCodigo) continue;
      _ultimoCodigo = codigo;
      final produto = estoque.porCodigo(codigo);
      final leitura = produto == null
          ? 'Código $codigo não cadastrado'
          : _adicionar(produto).$2;
      HapticFeedback.selectionClick();
      _limparLeitura?.cancel();
      _limparLeitura = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _leitura = null);
      });
      setState(() => _leitura = leitura);
      return;
    }
  }

  Future<void> _buscar() async {
    if (_camera) _escanear();
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

  Future<void> _digitarCodigo() async {
    if (_camera) _escanear();
    var codigo = '';
    final valor = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Digitar código manualmente'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(labelText: 'Código de barras'),
          onChanged: (texto) => codigo = texto.trim(),
          onSubmitted: (_) => Navigator.pop(dialogo, codigo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, codigo),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (valor == null || valor.isEmpty || !mounted) return;
    final codigoValido = codigoDeProduto(valor);
    if (codigoValido == null) {
      avisar(context, 'Digite o código impresso na embalagem.');
      return;
    }
    final produto = estoque.porCodigo(codigoValido);
    if (produto == null) {
      avisar(context, 'Código não cadastrado.');
      return;
    }
    final (ok, mensagem) = _adicionar(produto);
    if (!ok) avisar(context, mensagem);
  }

  void _finalizar() {
    final total = _total;
    final itens = [for (final i in _itens) ItemVenda(i.produto, i.quantidade)];
    final movs = estoque.registrarVenda(itens, pagamento: _pagamento);
    if (movs.isEmpty) {
      avisar(context, 'Confira as quantidades disponíveis antes de finalizar.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (widget.incorporada) {
      setState(() {
        _itens.clear();
        _pagamento = null;
        _camera = false;
        _leitura = null;
      });
    } else {
      Navigator.pop(context);
    }
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
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ColoredBox(
                  color: const Color(0xFF211633),
                  child: SizedBox(
                    height: 155,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_camera && widget.ativa)
                          MobileScanner(
                            key: ValueKey(_sessaoCamera),
                            fit: BoxFit.contain,
                            tapToFocus: true,
                            onDetect: _detectar,
                            errorBuilder: (context, erro) => avisoCameraLeitor(
                              erro,
                              tentarNovamente: () =>
                                  setState(() => _sessaoCamera++),
                            ),
                          )
                        else
                          Center(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _escanear,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Abrir câmera'),
                            ),
                          ),
                        if (_camera && widget.ativa)
                          IgnorePointer(
                            child: Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.68,
                                heightFactor: 0.62,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFB69CF2),
                                      width: 2.5,
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: Center(
                                    child: FractionallySizedBox(
                                      widthFactor: 0.82,
                                      child: SizedBox(
                                        height: 2,
                                        child: ColoredBox(
                                          color: Color(0xFFB69CF2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_camera && widget.ativa)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IconButton.filled(
                              tooltip: 'Fechar câmera',
                              onPressed: _escanear,
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: _digitarCodigo,
                child: const Text('Digitar código manualmente'),
              ),
              TextButton(onPressed: _buscar, child: const Text('Buscar')),
            ],
          ),
          if (_leitura != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Semantics(liveRegion: true, child: Text(_leitura!)),
            ),
          Expanded(
            child: _itens.isEmpty
                ? const EstadoVazio(
                    icone: Icons.point_of_sale,
                    titulo: 'Nenhum item na venda',
                    texto: 'Escaneie os códigos de barras ou busque os produtos. O estoque só baixa quando você finalizar.',
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.produto.validade case final data?)
                                    Text(
                                      'Primeiro lote: ${formatarData(data)}',
                                      style: t.bodySmall,
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatarPreco(item.produto.preco)} cada',
                                    style: t.bodySmall?.copyWith(
                                      color: AppCores.cinza,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'Tirar uma unidade de ',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _alterar(item, -1),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${item.quantidade}',
                                textAlign: TextAlign.center,
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'Adicionar uma unidade de ',
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
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final forma in const ['Pix', 'Dinheiro', 'Cartão'])
                          ChoiceChip(
                            label: Text(forma),
                            selected: _pagamento == forma,
                            showCheckmark: false,
                            onSelected: (valor) => setState(
                              () => _pagamento = valor ? forma : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _itens.isEmpty ? null : _finalizar,
                      child: Row(
                        children: [
                          const Expanded(child: Text('Finalizar venda')),
                          Text(formatarPreco(_total)),
                        ],
                      ),
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
    final lista =
        estoque.produtos
            .where(
              (p) =>
                  p.quantidade > 0 &&
                  (b.isEmpty ||
                      p.nome.toLowerCase().contains(b) ||
                      p.categoria.toLowerCase().contains(b) ||
                      (p.codigoBarras ?? '').contains(b)),
            )
            .toList()
          ..sort(
            (a, c) => a.nome.toLowerCase().compareTo(c.nome.toLowerCase()),
          );
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
                  hintText: 'Nome ou código de barras',
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
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
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
