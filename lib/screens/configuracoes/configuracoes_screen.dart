import 'package:stokio/theme/tema_preferencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stokio/services/backup_service.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/exportacao_service.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:stokio/services/notificacoes.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/widgets/dialogos.dart';
import 'package:stokio/utils/formatadores.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  Future<void> _mudarDias(int dias) async {
    await perfil.definirDiasAviso(dias);
    estoque.atualizarTela();
    if (mounted) setState(() {});
  }

  Future<void> _copiarBackup() async {
    await Clipboard.setData(ClipboardData(text: BackupService.exportar()));
    await perfil.registrarBackup();
    if (mounted) setState(() {});
    if (mounted) avisar(context, 'Backup copiado. Cole onde quiser guardar.');
  }

  Future<void> _compartilharBackup() async {
    final resultado = await Share.share(BackupService.exportar());
    if (resultado.status == ShareResultStatus.success) {
      await perfil.registrarBackup();
      if (mounted) setState(() {});
    }
  }

  Future<void> _restaurar({bool somenteTeste = false}) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _RestaurarDialog(),
    );
    if (texto == null || texto.trim().isEmpty || !mounted) return;

    try {
      final teste = BackupService.testar(texto);
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Backup válido'),
          content: Text(
            '${teste.produtos} produtos, ${teste.movimentos} movimentações e ${teste.fornecedores} fornecedores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) avisar(context, 'Arquivo de backup inválido ou incompleto.');
      return;
    }
    if (!mounted || somenteTeste) return;

    final ok = await confirmar(
      context,
      titulo: 'Substituir os dados?',
      texto: 'Os produtos e o histórico atuais serão trocados pelos do backup.',
      rotuloConfirmar: 'Restaurar',
      destrutivo: true,
    );
    if (!ok || !mounted) return;

    try {
      await BackupService.importar(texto);
      if (mounted) avisar(context, 'Backup restaurado.');
    } catch (_) {
      if (mounted) {
        avisar(
          context,
          'Não consegui ler esse backup. Confira o texto colado.',
        );
      }
    }
  }

  Future<void> _exemplo() async {
    final ok = await confirmar(
      context,
      titulo: 'Carregar dados de exemplo?',
      texto: 'Vamos adicionar produtos de exemplo aos que você já tem.',
      rotuloConfirmar: 'Carregar',
    );
    if (ok && mounted) {
      estoque.carregarExemplo();
      avisar(context, 'Dados de exemplo adicionados.');
    }
  }

  Future<void> _apagar() async {
    final ok = await confirmar(
      context,
      titulo: 'Apagar todos os dados?',
      texto: 'Todos os produtos e o histórico serão apagados deste aparelho. Isso não pode ser desfeito.',
      rotuloConfirmar: 'Apagar tudo',
      destrutivo: true,
    );
    if (ok && mounted) {
      estoque.apagarTudo();
      avisar(context, 'Dados apagados.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titulo = t.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    Widget opcao(
      IconData icone,
      String texto,
      VoidCallback aoTocar, {
      String? detalhe,
      bool perigo = false,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icone, color: perigo ? AppCores.zerado : null),
        title: Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: perigo ? AppCores.zerado : null,
          ),
        ),
        subtitle: detalhe == null ? null : Text(detalhe),
        onTap: aoTocar,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder(
                valueListenable: TemaPreferencia.modo,
                builder: (context, modo, _) =>
                    DropdownButtonFormField<ThemeMode>(
                      initialValue: modo,
                      decoration: const InputDecoration(
                        labelText: 'Aparência',
                        prefixIcon: Icon(Icons.contrast),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Seguir o aparelho'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Claro'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Escuro'),
                        ),
                      ],
                      onChanged: (novo) {
                        if (novo != null) TemaPreferencia.definir(novo);
                      },
                    ),
              ),
            ),
          ),
          if (Notificacoes.disponivel) ...[
            Text('Notificações no celular', style: titulo),
            opcao(
              Icons.notifications_active_outlined,
              'Ativar alertas sonoros',
              () async {
                if (await Notificacoes.ativar()) {
                  if (mounted)
                    avisar(context, 'Alertas disponíveis neste aparelho.');
                } else {
                  await Notificacoes.abrirConfiguracoes();
                }
              },
              detalhe: 'Estoque baixo, itens zerados e vencimentos do estoque local.',
            ),
            opcao(Icons.volume_up_outlined, 'Testar notificação', () async {
              if (!await Notificacoes.testar() && mounted) {
                avisar(context, 'Ative as notificações para receber o teste.');
              }
            }),
            const SizedBox(height: 16),
          ],
          Text('Aviso de validade', style: titulo),
          const SizedBox(height: 4),
          Text(
            'Quantos dias antes do vencimento o produto entra em alerta.',
            style: t.bodyMedium?.copyWith(
              color: context.cores.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final d in const [3, 7, 15, 30])
                  ButtonSegment(value: d, label: Text('$d dias')),
              ],
              selected: {perfil.diasAvisoValidade},
              onSelectionChanged: (s) => _mudarDias(s.first),
            ),
          ),
          const SizedBox(height: 28),
          Text('Backup', style: titulo),
          Text(
            perfil.ultimoBackup == null
                ? 'Nenhum backup registrado'
                : 'Último backup: ${formatarData(perfil.ultimoBackup!)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Seus dados ficam só neste aparelho. O backup leva tudo para outro celular.',
            style: t.bodyMedium?.copyWith(
              color: context.cores.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          opcao(
            Icons.ios_share,
            'Compartilhar backup',
            _compartilharBackup,
            detalhe: 'Envie por WhatsApp, e-mail ou salve nas notas.',
          ),
          opcao(Icons.copy_outlined, 'Copiar backup', _copiarBackup),
          opcao(
            Icons.verified_outlined,
            'Testar um backup',
            () => _restaurar(somenteTeste: true),
            detalhe: 'Verifica o texto sem substituir os dados atuais.',
          ),
          opcao(
            Icons.restore,
            'Restaurar backup',
            _restaurar,
            detalhe: 'Cole o texto de um backup anterior.',
          ),
          const SizedBox(height: 20),
          Text('Planilhas', style: titulo),
          const SizedBox(height: 4),
          opcao(
            Icons.table_chart_outlined,
            'Exportar estoque (CSV)',
            () => ExportacaoService.compartilhar(
              'estoque-stokio.csv',
              ExportacaoService.csvEstoque(),
            ),
            detalhe: 'Abre no Excel ou Google Planilhas.',
          ),
          opcao(
            Icons.history,
            'Exportar histórico (CSV)',
            () => ExportacaoService.compartilhar(
              'historico-stokio.csv',
              ExportacaoService.csvHistorico(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Dados', style: titulo),
          const SizedBox(height: 4),
          opcao(
            Icons.auto_awesome_outlined,
            'Carregar dados de exemplo',
            _exemplo,
          ),
          opcao(
            Icons.delete_outline,
            'Apagar todos os dados',
            _apagar,
            perigo: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Movimenta 1.8.2',
            style: t.bodySmall?.copyWith(color: context.cores.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RestaurarDialog extends StatefulWidget {
  const _RestaurarDialog();

  @override
  State<_RestaurarDialog> createState() => _RestaurarDialogState();
}

class _RestaurarDialogState extends State<_RestaurarDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restaurar backup'),
      content: TextField(
        controller: _controller,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Cole aqui o texto do backup',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
