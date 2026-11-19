import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movimenta/models/produto.dart';
import 'package:movimenta/screens/scanner/scanner_screen.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/widgets/campo_data.dart';

/// Cadastro e edição de produto.
/// Na edição a quantidade não aparece: ela muda por entradas, saídas e ajustes.
class ProdutoFormScreen extends StatefulWidget {
  const ProdutoFormScreen({super.key, this.produto, this.codigoInicial});

  final Produto? produto;

  /// Código já lido pelo scanner, para um produto novo.
  final String? codigoInicial;

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _chave = GlobalKey<FormState>();

  late final _nome = TextEditingController(text: widget.produto?.nome ?? '');
  late final _categoria =
      TextEditingController(text: widget.produto?.categoria ?? '');
  late final _codigo = TextEditingController(
    text: widget.produto?.codigoBarras ?? widget.codigoInicial ?? '',
  );
  late final _quantidade = TextEditingController();
  late final _minimo = TextEditingController(
    text: widget.produto == null ? '' : '${widget.produto!.minimo}',
  );
  late final _unidade =
      TextEditingController(text: widget.produto?.unidade ?? 'un');
  late final _preco = TextEditingController(
    text: widget.produto == null
        ? ''
        : widget.produto!.preco.toStringAsFixed(2).replaceAll('.', ','),
  );
  late DateTime? _validade = widget.produto?.validade;

  bool get _editando => widget.produto != null;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _categoria,
      _codigo,
      _quantidade,
      _minimo,
      _unidade,
      _preco
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

  String? _inteiro(String? v) {
    if (v == null || v.trim().isEmpty) return 'Preencha este campo.';
    return int.tryParse(v.trim()) == null ? 'Use só números.' : null;
  }

  String? _valor(String? v) {
    if (v == null || v.trim().isEmpty) return 'Preencha este campo.';
    return double.tryParse(v.trim().replaceAll(',', '.')) == null
        ? 'Use um valor como 12,50.'
        : null;
  }

  String? _validarCodigo(String? v) {
    final c = (v ?? '').trim();
    if (c.isEmpty) return null;
    return estoque.codigoEmUso(c, exceto: widget.produto?.id)
        ? 'Este código já está em outro produto.'
        : null;
  }

  Future<void> _escanear() async {
    final c = await lerCodigo(context);
    if (c != null && mounted) setState(() => _codigo.text = c);
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;

    final preco = double.parse(_preco.text.trim().replaceAll(',', '.'));
    final minimo = int.parse(_minimo.text.trim());
    final codigo = _codigo.text.trim().isEmpty ? null : _codigo.text.trim();

    if (_editando) {
      final p = widget.produto!;
      p
        ..nome = _nome.text.trim()
        ..categoria = _categoria.text.trim()
        ..minimo = minimo
        ..unidade = _unidade.text.trim()
        ..preco = preco
        ..codigoBarras = codigo
        ..validade = _validade;
      estoque.salvarAlteracoes(p);
    } else {
      estoque.adicionar(
        Produto(
          id: estoque.novoId(),
          nome: _nome.text.trim(),
          categoria: _categoria.text.trim(),
          quantidade: int.parse(_quantidade.text.trim()),
          minimo: minimo,
          preco: preco,
          unidade: _unidade.text.trim(),
          codigoBarras: codigo,
          validade: _validade,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final apenasNumeros = [FilteringTextInputFormatter.digitsOnly];
    final sugestoes = estoque.categorias.take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar produto' : 'Novo produto'),
      ),
      body: Form(
        key: _chave,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Código de barras (opcional)',
                suffixIcon: IconButton(
                  tooltip: 'Escanear código de barras',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _escanear,
                ),
              ),
              validator: _validarCodigo,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoria,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Categoria'),
              validator: _obrigatorio,
            ),
            if (sugestoes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final c in sugestoes)
                    ActionChip(
                      label: Text(c),
                      onPressed: () => setState(() => _categoria.text = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_editando) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _quantidade,
                      keyboardType: TextInputType.number,
                      inputFormatters: apenasNumeros,
                      decoration:
                          const InputDecoration(labelText: 'Quantidade atual'),
                      validator: _inteiro,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType: TextInputType.number,
                    inputFormatters: apenasNumeros,
                    decoration:
                        const InputDecoration(labelText: 'Estoque mínimo'),
                    validator: _inteiro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unidade,
                    decoration: const InputDecoration(
                      labelText: 'Unidade',
                      hintText: 'un, kg, cx',
                    ),
                    validator: _obrigatorio,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preco,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preço',
                      prefixText: 'R\$ ',
                    ),
                    validator: _valor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CampoData(
              rotulo: 'Data de validade (opcional)',
              valor: _validade,
              aoMudar: (d) => setState(() => _validade = d),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _salvar,
              child: Text(_editando ? 'Salvar alterações' : 'Salvar produto'),
            ),
          ],
        ),
      ),
    );
  }
}
