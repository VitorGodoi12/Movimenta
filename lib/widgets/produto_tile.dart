import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/nivel_estoque.dart';
import 'package:stokio/widgets/selo_situacao.dart';

class ProdutoTile extends StatelessWidget {
  const ProdutoTile({super.key, required this.produto, this.onTap, this.acao});

  final Produto produto;
  final VoidCallback? onTap;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final validade = produto.validade;
    // Produto sem estoque não precisa de alerta de validade.
    final situacaoValidade = produto.quantidade > 0
        ? produto.situacaoValidade(perfil.diasAvisoValidade)
        : SituacaoValidade.ok;
    final local = (produto.local ?? '').trim();
    final detalhe = [
      if (local.isNotEmpty) local,
      if (produto.unidadesPorCaixa > 0)
        'Caixa: ${produto.unidadesPorCaixa} ${produto.unidade}',
      if (produto.unidadesPorFardo > 0)
        'Fardo: ${produto.unidadesPorFardo} ${produto.unidade}',
      if (local.isEmpty &&
          produto.unidadesPorCaixa == 0 &&
          produto.unidadesPorFardo == 0)
        produto.categoria,
    ].join(' · ');
    final inicial = produto.nome.trim().isEmpty
        ? '?'
        : produto.nome.trim()[0].toUpperCase();

    return Material(
      color: AppCores.branco,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppCores.linha),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A cor do avatar já mostra a situação do estoque.
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: produto.situacao.fundo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      inicial,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.nome,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detalhe,
                          style: t.bodySmall?.copyWith(color: AppCores.cinza),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${produto.quantidade} ${produto.unidade}',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SeloSituacao(situacao: produto.situacao),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              NivelEstoque(produto: produto),
              const SizedBox(height: 10),
              Text('Mínimo ${produto.minimo}', style: t.bodySmall),
              if (validade != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: AppCores.cinza,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Validade ${formatarData(validade)}',
                        style: t.bodySmall?.copyWith(color: AppCores.cinza),
                      ),
                    ),
                    SeloValidade(
                      situacao: situacaoValidade,
                      dias: produto.diasParaVencer,
                    ),
                  ],
                ),
              ],
              if (acao != null) ...[const SizedBox(height: 6), acao!],
            ],
          ),
        ),
      ),
    );
  }
}
