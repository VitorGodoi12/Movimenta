import 'package:flutter/material.dart';
import 'package:movimenta/models/movimentacao.dart';
import 'package:movimenta/screens/configuracoes/configuracoes_screen.dart';
import 'package:movimenta/screens/estoque/produto_detalhe_screen.dart';
import 'package:movimenta/screens/estoque/produto_form_screen.dart';
import 'package:movimenta/screens/scanner/fluxo_scanner.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/theme/app_theme.dart';
import 'package:movimenta/utils/formatadores.dart';
import 'package:movimenta/widgets/movimentacao_tile.dart';
import 'package:movimenta/widgets/movimentar_sheet.dart';
import 'package:movimenta/widgets/produto_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.irPara});

  /// Troca a aba da barra inferior (2 = Alertas, 3 = Histórico).
  final ValueChanged<int> irPara;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: Listenable.merge([estoque, perfil]),
      builder: (context, _) {
        final cliente = perfil.cliente;
        final alertas = estoque.alertas.take(3).toList();
        final recentes = estoque.historico.take(4).toList();
        final vencimentos = estoque.vencidos.length + estoque.vencendo.length;

        return Scaffold(
          appBar: AppBar(
            title: Text('Olá, ${cliente?.primeiroNome ?? ''}'),
            actions: [
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfiguracoesScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppCores.roxo,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente?.estabelecimento ?? 'Meu estoque',
                      style:
                          t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Em estoque: ${formatarPreco(estoque.valorEmEstoque)}',
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _Contador(
                              valor: estoque.total, rotulo: 'produtos'),
                        ),
                        Expanded(
                          child: _Contador(
                              valor: estoque.baixos.length,
                              rotulo: 'acabando'),
                        ),
                        Expanded(
                          child: _Contador(
                              valor: estoque.zerados.length,
                              rotulo: 'zerados'),
                        ),
                        Expanded(
                          child: _Contador(
                              valor: vencimentos, rotulo: 'vencendo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => mostrarMovimentarSheet(context,
                          tipo: TipoMovimento.entrada),
                      icon: const Icon(Icons.add),
                      label: const Text('Entrada'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => mostrarMovimentarSheet(context,
                          tipo: TipoMovimento.saida),
                      icon: const Icon(Icons.remove),
                      label: const Text('Saída'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => escanearEAbrir(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear código de barras'),
              ),
              const SizedBox(height: 28),
              if (estoque.total == 0)
                const _PrimeirosPassos()
              else ...[
                _Secao(
                  titulo: 'Precisa de atenção',
                  onVerTodos: () => irPara(2),
                ),
                const SizedBox(height: 8),
                if (alertas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Tudo certo por aqui. Nada acabando, zerado ou vencendo.',
                      style: t.bodyMedium?.copyWith(color: AppCores.cinza),
                    ),
                  )
                else
                  for (final p in alertas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProdutoTile(
                        produto: p,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProdutoDetalheScreen(produto: p),
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                _Secao(
                  titulo: 'Últimas movimentações',
                  onVerTodos: () => irPara(3),
                ),
                for (final m in recentes) MovimentacaoTile(mov: m),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PrimeirosPassos extends StatelessWidget {
  const _PrimeirosPassos();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.roxoSuave,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu estoque está vazio',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cadastre o primeiro produto (dá para escanear o código de barras) ou veja o app com dados de exemplo.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProdutoFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar primeiro produto'),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: estoque.carregarExemplo,
              child: const Text('Ver com dados de exemplo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$valor',
          style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(rotulo, style: t.bodySmall),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.onVerTodos});

  final String titulo;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onVerTodos, child: const Text('Ver todos')),
      ],
    );
  }
}
