import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/campo_data.dart';

/// Folha para registrar entrada, saída ou ajuste de contagem.
/// Se [produto] for informado, ele já vem escolhido.
Future<void> mostrarMovimentarSheet(
  BuildContext context, {
  Produto? produto,
  TipoMovimento tipo = TipoMovimento.entrada,
  String? motivo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppCores.branco,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MovimentarSheet(
      produto: produto,
      tipoInicial: tipo,
      motivoInicial: motivo,
    ),
  );
}

class _MovimentarSheet extends StatefulWidget {
  const _MovimentarSheet({
    this.produto,
    required this.tipoInicial,
    this.motivoInicial,
  });

  final Produto? produto;
  final TipoMovimento tipoInicial;
  final String? motivoInicial;

  @override
  State<_MovimentarSheet> createState() => _MovimentarSheetState();
}

class _MovimentarSheetState extends State<_MovimentarSheet> {
  late TipoMovimento _tipo = widget.tipoInicial;
  late Produto? _produto = widget.produto;
  late String? _motivo =
      widget.motivoInicial ?? _motivoPadrao(widget.tipoInicial);
  DateTime? _validade;
  final _quantidade = TextEditingController();
  String? _erro;

  String? _motivoPadrao(TipoMovimento t) => switch (t) {
        TipoMovimento.entrada => Motivos.compra,
        TipoMovimento.saida => Motivos.venda,
        _ => null,
      };

  List<String> get _motivos => switch (_tipo) {
        TipoMovimento.entrada => Motivos.entrada,
        TipoMovimento.saida => Motivos.saida,
        _ => const <String>[],
      };

  @override
  void dispose() {
    _quantidade.dispose();
    super.dispose();
  }

  Future<void> _escanear() async {
    final codigo = await lerCodigo(context);
    if (codigo == null || !mounted) return;
    final p = estoque.porCodigo(codigo);
    setState(() {
      if (p != null) {
        _produto = p;
        _erro = null;
      } else {
        _erro = 'O código $codigo não está cadastrado.';
      }
    });
  }

  void _confirmar() {
    final p = _produto;
    final qtd = int.tryParse(_quantidade.text.trim());
    final ajuste = _tipo == TipoMovimento.ajuste;

    if (p == null) {
      setState(() => _erro = 'Escolha um produto.');
      return;
    }
    if (qtd == null || (!ajuste && qtd <= 0)) {
      setState(() => _erro = ajuste
          ? 'Digite a quantidade contada.'
          : 'Digite uma quantidade maior que zero.');
      return;
    }
    if (_tipo == TipoMovimento.saida && qtd > p.quantidade) {
      setState(
          () => _erro = 'Só há ${p.quantidade} ${p.unidade} em estoque.');
      return;
    }

    final mov = estoque.movimentar(
      p,
      _tipo,
      qtd,
      motivo: _motivo,
      validade: _tipo == TipoMovimento.entrada ? _validade : null,
    );

    final texto = mov == null
        ? 'A contagem já estava correta.'
        : switch (_tipo) {
            TipoMovimento.entrada =>
              'Entrada registrada: +$qtd ${p.unidade} de ${p.nome}.',
            TipoMovimento.saida =>
              'Saída registrada: -${-mov.delta} ${p.unidade} de ${p.nome}.',
            _ => 'Contagem ajustada: ${p.nome} agora tem ${p.quantidade} ${p.unidade}.',
          };

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          action: mov == null
              ? null
              : SnackBarAction(
                  label: 'Desfazer',
                  textColor: AppCores.roxo,
                  onPressed: () => estoque.desfazer(mov),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final ajuste = _tipo == TipoMovimento.ajuste;

    final titulo = switch (_tipo) {
      TipoMovimento.entrada => 'Registrar entrada',
      TipoMovimento.saida => 'Registrar saída',
      _ => 'Ajustar contagem',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + teclado),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TipoMovimento>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TipoMovimento.entrada, label: Text('Entrada')),
                  ButtonSegment(
                      value: TipoMovimento.saida, label: Text('Saída')),
                  ButtonSegment(
                      value: TipoMovimento.ajuste, label: Text('Ajuste')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() {
                  _tipo = s.first;
                  _motivo = _motivoPadrao(_tipo);
                  _erro = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.produto != null)
              Text(
                widget.produto!.nome,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Produto>(
                      value: _produto,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Produto'),
                      items: [
                        for (final p in estoque.produtos)
                          DropdownMenuItem(
                            value: p,
                            child:
                                Text(p.nome, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (p) => setState(() {
                        _produto = p;
                        _erro = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Escanear código de barras',
                    style: IconButton.styleFrom(
                      backgroundColor: AppCores.roxo,
                      foregroundColor: AppCores.preto,
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _escanear,
                  ),
                ],
              ),
            if (_produto != null) ...[
              const SizedBox(height: 6),
              Text(
                'No sistema agora: ${_produto!.quantidade} ${_produto!.unidade}',
                style: t.bodySmall?.copyWith(color: AppCores.cinza),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _quantidade,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: ajuste ? 'Contagem real' : 'Quantidade',
                helperText: ajuste
                    ? 'Quantas unidades existem agora. O sistema corrige a diferença.'
                    : null,
                helperMaxLines: 2,
                suffixText: _produto?.unidade,
              ),
              onChanged: (_) => setState(() => _erro = null),
            ),
            if (_motivos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Motivo',
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in _motivos)
                    ChoiceChip(
                      label: Text(m),
                      selected: _motivo == m,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _motivo = m),
                    ),
                ],
              ),
            ],
            if (_tipo == TipoMovimento.entrada) ...[
              const SizedBox(height: 16),
              CampoData(
                rotulo: 'Validade desta entrada (opcional)',
                valor: _validade,
                aoMudar: (d) => setState(() => _validade = d),
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(
                _erro!,
                style: t.bodySmall?.copyWith(
                  color: AppCores.zerado,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _confirmar, child: const Text('Confirmar')),
          ],
        ),
      ),
    );
  }
}
