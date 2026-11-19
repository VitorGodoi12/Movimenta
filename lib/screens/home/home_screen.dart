import 'package:flutter/material.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/screens/alertas/lista_compras_screen.dart';
import 'package:stokio/screens/configuracoes/configuracoes_screen.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
import 'package:stokio/screens/estoque/importar_estoque_screen.dart';
import 'package:stokio/screens/scanner/fluxo_scanner.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/widgets/marca_stokio.dart';
import 'package:stokio/widgets/movimentar_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.abrirEstoque,
    required this.abrirVenda,
  });

  final VoidCallback abrirEstoque;
  final VoidCallback abrirVenda;

  Future<T?> _abrir<T>(BuildContext context, Widget tela) =>
      Navigator.push<T>(context, MaterialPageRoute(builder: (_) => tela));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const MarcaStokio()),
      body: ListenableBuilder(
        listenable: Listenable.merge([estoque, perfil]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          children: [
            Text(descricaoHoje(), style: t.bodyMedium),
            Text(
              perfil.cliente?.estabelecimento ?? 'Meu estoque',
              style: t.headlineSmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppCores.roxo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Valor em estoque'),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: estoque.valorEmEstoque),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, valor, _) => Text(
                      formatarPreco(valor),
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: abrirVenda,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Venda rápida'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Escanear'),
                  onPressed: () => escanearEAbrir(context),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Entrada'),
                  onPressed: () => mostrarMovimentarSheet(
                    context,
                    tipo: TipoMovimento.entrada,
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Importar lista'),
                  onPressed: () async {
                    final total = await _abrir<int>(
                      context,
                      const ImportarEstoqueScreen(),
                    );
                    if (total != null && context.mounted) {
                      abrirEstoque();
                      avisar(context, '$total produtos importados.');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Seu estoque', style: t.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text('${estoque.total} produtos'),
                  onPressed: abrirEstoque,
                ),
                for (final (filtro, numero, nome) in [
                  (FiltroEstoque.acabando, estoque.baixos.length, 'acabando'),
                  (FiltroEstoque.zerados, estoque.zerados.length, 'zerados'),
                  (
                    FiltroEstoque.vencendo,
                    estoque.vencidos.length + estoque.vencendo.length,
                    'vencendo',
                  ),
                ])
                  ActionChip(
                    label: Text('$numero $nome'),
                    onPressed: () => _abrir<void>(
                      context,
                      EstoqueScreen(filtroInicial: filtro),
                    ),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('Repor estoque'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir<void>(context, const ListaComprasScreen()),
            ),
            if (perfil.backupPendente)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Faça um backup do estoque'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrir<void>(context, const ConfiguracoesScreen()),
              ),
            if (estoque.maisVendidos().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Saída rápida', style: t.titleMedium),
              for (final produto in estoque.maisVendidos())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(produto.nome),
                  subtitle: Text(
                    '${produto.quantidade} ${produto.unidade} em estoque',
                  ),
                  trailing: IconButton.outlined(
                    tooltip: 'Vender uma unidade de ${produto.nome}',
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      final mov = estoque.movimentar(
                        produto,
                        TipoMovimento.saida,
                        1,
                        motivo: Motivos.venda,
                      );
                      if (mov != null)
                        avisarComDesfazer(context, 'Unidade vendida.', [mov]);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
