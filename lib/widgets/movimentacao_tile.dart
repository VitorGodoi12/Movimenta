import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';

class MovimentacaoTile extends StatelessWidget {
  const MovimentacaoTile({super.key, required this.mov});

  final Movimentacao mov;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final (icone, titulo) = switch (mov.tipo) {
      TipoMovimento.entrada => (Icons.add, 'Entrada'),
      TipoMovimento.saida => (Icons.remove, 'Saída'),
      TipoMovimento.ajuste => (Icons.tune, 'Ajuste de contagem'),
      TipoMovimento.cadastro => (
        Icons.inventory_2_outlined,
        'Cadastro inicial',
      ),
    };
    final motivo = mov.motivo == null ? '' : ' (${mov.motivo})';
    final valor = '${mov.delta > 0 ? '+' : ''}${mov.delta}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.cores.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov.produtoNome,
                  style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$titulo$motivo, ${formatarQuando(mov.data)}',
                  style: t.bodySmall?.copyWith(
                    color: context.cores.onSurfaceVariant,
                  ),
                ),
                if (mov.pagamento case final pagamento?)
                  Text('Pagamento: $pagamento', style: t.bodySmall),
              ],
            ),
          ),
          Text(
            valor,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
