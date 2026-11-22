import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/aparecer.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/movimentacao_tile.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';
import 'package:stokio/widgets/nivel_estoque.dart';
import 'package:stokio/widgets/selo_situacao.dart';

class ProdutoDetalheScreen extends StatelessWidget {
  const ProdutoDetalheScreen({super.key, required this.produto});

  final Produto produto;

  String? _avisoLote(DateTime? data) {
    if (data == null) return null;
    final dias = -diasDesde(data);
    if (dias < 0) return 'Vencido';
    if (dias == 0) return 'Vence hoje';
    if (dias <= perfil.diasAvisoValidade) {
      return dias == 1 ? 'Vence amanhã' : 'Vence em $dias dias';
    }
    return null;
  }

  Future<void> _excluir(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir produto?',
      texto:
          '"${produto.nome}" será removido do estoque. O histórico de movimentações continua guardado.',
      rotuloConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (ok && context.mounted) {
      estoque.remover(produto);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: Listenable.merge([estoque, perfil]),
      builder: (context, _) {
        final historico = estoque.historico
            .where((m) => m.produtoId == produto.id)
            .take(5)
            .toList();
        final validade = produto.validade;
        final situacaoValidade = produto.quantidade > 0
            ? produto.situacaoValidade(perfil.diasAvisoValidade)
            : SituacaoValidade.ok;
        final fornecedor = estoque.fornecedorDe(produto);
        final margem = produto.margem;
        final local = (produto.local ?? '').trim();

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Editar produto',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProdutoFormScreen(produto: produto),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Excluir produto',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _excluir(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Text(
                produto.nome,
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                local.isEmpty
                    ? produto.categoria
                    : '${produto.categoria}, $local',
                style: t.bodyMedium?.copyWith(color: AppCores.cinza),
              ),
              const SizedBox(height: 20),
              Aparecer(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppCores.roxoSuave,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${produto.quantidade}',
                            style: t.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${produto.unidade} em estoque',
                              style: t.bodyMedium,
                            ),
                          ),
                          const Spacer(),
                          SeloSituacao(situacao: produto.situacao),
                        ],
                      ),
                      const SizedBox(height: 18),
                      NivelEstoque(produto: produto, altura: 12),
                      const SizedBox(height: 8),
                      Text(
                        'O traço preto marca o mínimo: ${produto.minimo} ${produto.unidade}',
                        style: t.bodySmall?.copyWith(color: AppCores.cinza),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => mostrarMovimentarSheet(
                        context,
                        produto: produto,
                        tipo: TipoMovimento.entrada,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Entrada'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => mostrarMovimentarSheet(
                        context,
                        produto: produto,
                        tipo: TipoMovimento.saida,
                      ),
                      icon: const Icon(Icons.remove),
                      label: const Text('Saída'),
                    ),
                  ),
                ],
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => mostrarMovimentarSheet(
                    context,
                    produto: produto,
                    tipo: TipoMovimento.ajuste,
                  ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Ajustar contagem'),
                ),
              ),
              const SizedBox(height: 12),
              if (validade != null)
                _Linha(
                  rotulo: 'Validade',
                  valor: formatarData(validade),
                  complemento: situacaoValidade == SituacaoValidade.ok
                      ? null
                      : SeloValidade(
                          situacao: situacaoValidade,
                          dias: produto.diasParaVencer,
                        ),
                )
              else
                const _Linha(rotulo: 'Validade', valor: 'Não informada'),
              _Linha(
                rotulo: 'Preço de venda',
                valor: formatarPreco(produto.preco),
              ),
              if (produto.custo > 0)
                _Linha(
                  rotulo: 'Preço de custo',
                  valor: formatarPreco(produto.custo),
                ),
              if (margem != null)
                _Linha(rotulo: 'Margem', valor: formatarPercentual(margem)),
              _Linha(
                rotulo: 'Valor em estoque',
                valor: formatarPreco(produto.valorEmEstoque),
              ),
              _Linha(rotulo: 'Estoque mínimo', valor: '${produto.minimo}'),
              _Linha(
                rotulo: 'Local',
                valor: local.isEmpty ? 'Não informado' : local,
              ),
              _Linha(
                rotulo: 'Fornecedor',
                valor: fornecedor?.nome ?? 'Não informado',
              ),
              _Linha(
                rotulo: 'Código de barras',
                valor: produto.codigoBarras ?? 'Não informado',
              ),
              const SizedBox(height: 24),
              if (produto.lotes.isNotEmpty) ...[
                Text('Lotes em estoque', style: t.titleMedium),
                for (final MapEntry(key: data, value: saldo)
                    in produto.lotes.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      data == null
                          ? 'Sem validade informada'
                          : formatarData(data),
                    ),
                    subtitle: _avisoLote(data) == null
                        ? null
                        : Text(_avisoLote(data)!),
                    trailing: Text('$saldo ${produto.unidade}'),
                  ),
                const SizedBox(height: 16),
              ],
              Text(
                'Movimentações deste produto',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              if (historico.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhuma movimentação ainda. Registre uma entrada ou saída.',
                    style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                  ),
                )
              else
                for (final m in historico) MovimentacaoTile(mov: m),
            ],
          ),
        );
      },
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor, this.complemento});

  final String rotulo;
  final String valor;
  final Widget? complemento;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: Row(
        children: [
          Text(rotulo, style: t.bodyMedium?.copyWith(color: AppCores.cinza)),
          const SizedBox(width: 16),
          const Spacer(),
          if (complemento != null) ...[complemento!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
