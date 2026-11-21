import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/nivel_estoque.dart';
import 'package:stokio/widgets/selo_situacao.dart';

class ProdutoTile extends StatelessWidget {
  const ProdutoTile({
    super.key,
    required this.produto,
    this.onTap,
    this.acao,
    this.compacto = false,
  });

  final Produto produto;
  final VoidCallback? onTap;
  final Widget? acao;
  final bool compacto;

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

    if (compacto) {
      final fundo = produto.situacao.fundo;
      final cor = switch (produto.situacao) {
        SituacaoEstoque.zerado => AppCores.zerado,
        SituacaoEstoque.baixo => const Color(0xFF845300),
        SituacaoEstoque.normal => AppCores.verdeForte,
      };
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppCores.verdeSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  inicial,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppCores.verdeForte,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.nome,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      validade == null
                          ? detalhe
                          : 'Vence ${formatarData(validade)}',
                      style: t.bodySmall?.copyWith(color: AppCores.cinza),
                    ),
                    if (produto.minimo > 0) ...[
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: (produto.quantidade / (produto.minimo * 2))
                            .clamp(0.0, 1.0),
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: AppCores.fundo,
                        color: produto.situacao == SituacaoEstoque.baixo
                            ? AppCores.baixo
                            : cor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: fundo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${produto.quantidade} ${produto.unidade}',
                  style: t.labelMedium?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
