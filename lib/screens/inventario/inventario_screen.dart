import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/scanner/scanner_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/estado_vazio.dart';

/// Conferência do estoque: digite a contagem real de cada produto
/// e aplique todos os ajustes de uma vez.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final Map<String, TextEditingController> _campos = {};
  late final List<Produto> _produtos;
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    // Ordena por local, para contar prateleira por prateleira.
    _produtos = [...estoque.produtos]
      ..sort((a, b) {
        final la = (a.local ?? '').toLowerCase();
        final lb = (b.local ?? '').toLowerCase();
        final c = la.compareTo(lb);
        return c != 0
            ? c
            : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    for (final p in _produtos) {
      _campos[p.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Contagens digitadas que diferem do estoque atual.
  Map<String, int> get _diferencas {
    final r = <String, int>{};
    for (final p in _produtos) {
      final v = int.tryParse(_campos[p.id]!.text.trim());
      if (v != null && v != p.quantidade) r[p.id] = v;
    }
    return r;
  }

  Future<void> _escanear() async {
    final codigo = await lerCodigo(context);
    if (codigo == null || !mounted) return;
    final p = estoque.porCodigo(codigo);
    if (p == null) {
      avisar(context, 'O código $codigo não está cadastrado.');
      return;
    }
    _buscaCtrl.text = p.nome;
    setState(() => _busca = p.nome);
  }

  Future<void> _aplicar() async {
    final dif = _diferencas;
    final ok = await confirmar(
      context,
      titulo: 'Aplicar contagem?',
      texto:
          '${dif.length} ${dif.length == 1 ? 'produto será ajustado' : 'produtos serão ajustados'}. Dá para desfazer logo depois.',
      rotuloConfirmar: 'Aplicar',
    );
    if (!ok || !mounted) return;

    final movs = estoque.aplicarContagens(dif);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Inventário aplicado: ${movs.length} ajustes.'),
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
    final b = _busca.trim().toLowerCase();
    final lista = _produtos
        .where(
          (p) =>
              b.isEmpty ||
              p.nome.toLowerCase().contains(b) ||
              (p.local ?? '').toLowerCase().contains(b) ||
              (p.codigoBarras ?? '').contains(b),
        )
        .toList();
    final qtdDiferencas = _diferencas.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventário')),
      body: _produtos.isEmpty
          ? const EstadoVazio(
              icone: Icons.fact_check_outlined,
              titulo: 'Nada para contar',
              texto: 'Cadastre produtos para fazer o inventário.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digite quantas unidades existem de verdade. Deixe em branco o que não contou.',
                        style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _buscaCtrl,
                        onChanged: (v) => setState(() => _busca = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome, local ou código',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Escanear código de barras',
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _escanear,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppCores.linha),
                    itemBuilder: (context, i) {
                      final p = lista[i];
                      final local = (p.local ?? '').trim();
                      return Padding(
                        key: ValueKey(p.id),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nome,
                                    style: t.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'No sistema: ${p.quantidade} ${p.unidade}${local.isEmpty ? '' : ', $local'}',
                                    style: t.bodySmall?.copyWith(
                                      color: AppCores.cinza,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _campos[p.id],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'Contei',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
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
                      padding: const EdgeInsets.all(20),
                      child: FilledButton(
                        onPressed: qtdDiferencas == 0 ? null : _aplicar,
                        child: Text(
                          qtdDiferencas == 0
                              ? 'Nenhuma diferença encontrada'
                              : 'Aplicar contagem ($qtdDiferencas)',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
