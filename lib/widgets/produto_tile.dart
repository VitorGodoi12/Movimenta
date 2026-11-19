import 'package:flutter/material.dart';
import 'package:movimenta/models/produto.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/theme/app_theme.dart';
import 'package:movimenta/utils/formatadores.dart';
import 'package:movimenta/widgets/nivel_estoque.dart';
import 'package:movimenta/widgets/selo_situacao.dart';

class ProdutoTile extends StatelessWidget {
  const ProdutoTile({
    super.key,
    required this.produto,
    this.onTap,
    this.acao,
  });

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

    return Material(
      color: AppCores.branco,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.nome,
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          produto.categoria,
                          style: t.bodySmall?.copyWith(color: AppCores.cinza),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SeloSituacao(situacao: produto.situacao),
                ],
              ),
              const SizedBox(height: 14),
              NivelEstoque(produto: produto),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${produto.quantidade} ${produto.unidade}',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'mínimo ${produto.minimo}',
                    style: t.bodySmall?.copyWith(color: AppCores.cinza),
                  ),
                ],
              ),
              if (validade != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 16, color: AppCores.cinza),
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
              if (acao != null) ...[
                const SizedBox(height: 6),
                acao!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
