import 'package:flutter/material.dart';
import 'package:stokio/models/fornecedor.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/whatsapp.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/estado_vazio.dart';

class FornecedoresScreen extends StatelessWidget {
  const FornecedoresScreen({super.key});

  void _abrirFormulario(BuildContext context, [Fornecedor? fornecedor]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.cores.surface,
      builder: (_) => _FornecedorSheet(fornecedor: fornecedor),
    );
  }

  Future<void> _chamar(BuildContext context, Fornecedor f) async {
    final ok = await abrirWhatsapp(f.telefone, 'Olá!');
    if (!ok && context.mounted) {
      avisar(context, 'Não consegui abrir o WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: estoque,
      builder: (context, _) {
        final lista = [
          ...estoque.fornecedores,
        ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        return Scaffold(
          appBar: AppBar(title: const Text('Fornecedores')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _abrirFormulario(context),
            icon: const Icon(Icons.add),
            label: const Text('Novo fornecedor'),
          ),
          body: lista.isEmpty
              ? const EstadoVazio(
                  icone: Icons.local_shipping_outlined,
                  titulo: 'Nenhum fornecedor ainda',
                  texto: 'Cadastre quem vende para você. Na lista de compras dá para fazer o pedido pelo WhatsApp.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final f = lista[i];
                    final qtd = estoque.produtosDoFornecedor(f);
                    return Material(
                      color: context.cores.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: context.cores.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => _abrirFormulario(context, f),
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                        title: Text(
                          f.nome,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${f.telefone.isEmpty ? 'Sem telefone' : f.telefone}, $qtd ${qtd == 1 ? 'produto' : 'produtos'}',
                          style: t.bodySmall,
                        ),
                        trailing: f.telefone.isEmpty
                            ? null
                            : IconButton.filled(
                                tooltip: 'Chamar no WhatsApp',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppCores.roxo,
                                  foregroundColor: AppCores.preto,
                                ),
                                icon: const Icon(Icons.chat_outlined),
                                onPressed: () => _chamar(context, f),
                              ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _FornecedorSheet extends StatefulWidget {
  const _FornecedorSheet({this.fornecedor});

  final Fornecedor? fornecedor;

  @override
  State<_FornecedorSheet> createState() => _FornecedorSheetState();
}

class _FornecedorSheetState extends State<_FornecedorSheet> {
  final _chave = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.fornecedor?.nome ?? '');
  late final _telefone = TextEditingController(
    text: widget.fornecedor?.telefone ?? '',
  );

  late final _prazo = TextEditingController(
    text: (widget.fornecedor?.prazoDias ?? 3).toString(),
  );

  bool get _editando => widget.fornecedor != null;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _prazo.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;
    if (_editando) {
      widget.fornecedor!
        ..nome = _nome.text.trim()
        ..telefone = _telefone.text.trim()
        ..prazoDias = int.parse(_prazo.text.trim());
      estoque.salvarFornecedor(widget.fornecedor!);
    } else {
      estoque.adicionarFornecedor(
        Fornecedor(
          id: estoque.novoId(),
          nome: _nome.text.trim(),
          telefone: _telefone.text.trim(),
          prazoDias: int.parse(_prazo.text.trim()),
        ),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final f = widget.fornecedor!;
    final ok = await confirmar(
      context,
      titulo: 'Excluir fornecedor?',
      texto:
          '"${f.nome}" será removido. Os produtos dele continuam no estoque, só sem fornecedor.',
      rotuloConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (ok && mounted) {
      estoque.removerFornecedor(f);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + teclado),
      child: SingleChildScrollView(
        child: Form(
          key: _chave,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando ? 'Editar fornecedor' : 'Novo fornecedor',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Preencha este campo.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telefone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (opcional)',
                  hintText: 'DDD + número',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _prazo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prazo de entrega em dias',
                ),
                validator: (v) {
                  final dias = int.tryParse((v ?? '').trim());
                  return dias == null || dias < 0 || dias > 365
                      ? 'Informe de 0 a 365 dias.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _salvar, child: const Text('Salvar')),
              if (_editando)
                Center(
                  child: TextButton(
                    onPressed: _excluir,
                    style: TextButton.styleFrom(
                      foregroundColor: AppCores.zerado,
                    ),
                    child: const Text('Excluir fornecedor'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
