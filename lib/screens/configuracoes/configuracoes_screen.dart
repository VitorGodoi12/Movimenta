import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:movimenta/services/backup_service.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:movimenta/theme/app_theme.dart';
import 'package:movimenta/widgets/dialogos.dart';

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
    if (mounted) avisar(context, 'Backup copiado. Cole onde quiser guardar.');
  }

  Future<void> _restaurar() async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _RestaurarDialog(),
    );
    if (texto == null || texto.trim().isEmpty || !mounted) return;

    final ok = await confirmar(
      context,
      titulo: 'Substituir os dados?',
      texto:
          'Os produtos e o histórico atuais serão trocados pelos do backup.',
      rotuloConfirmar: 'Restaurar',
      destrutivo: true,
    );
    if (!ok || !mounted) return;

    try {
      await BackupService.importar(texto);
      if (mounted) avisar(context, 'Backup restaurado.');
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não consegui ler esse backup. Confira o texto colado.');
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
      texto:
          'Todos os produtos e o histórico serão apagados deste aparelho. Isso não pode ser desfeito.',
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

    Widget opcao(IconData icone, String texto, VoidCallback aoTocar,
        {String? detalhe, bool perigo = false}) {
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
          Text('Aviso de validade', style: titulo),
          const SizedBox(height: 4),
          Text(
            'Quantos dias antes do vencimento o produto entra em alerta.',
            style: t.bodyMedium?.copyWith(color: AppCores.cinza),
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
          const SizedBox(height: 4),
          Text(
            'Seus dados ficam só neste aparelho. O backup leva tudo para outro celular.',
            style: t.bodyMedium?.copyWith(color: AppCores.cinza),
          ),
          const SizedBox(height: 4),
          opcao(
            Icons.ios_share,
            'Compartilhar backup',
            () => Share.share(BackupService.exportar()),
            detalhe: 'Envie por WhatsApp, e-mail ou salve nas notas.',
          ),
          opcao(Icons.copy_outlined, 'Copiar backup', _copiarBackup),
          opcao(
            Icons.restore,
            'Restaurar backup',
            _restaurar,
            detalhe: 'Cole o texto de um backup anterior.',
          ),
          const SizedBox(height: 20),
          Text('Dados', style: titulo),
          const SizedBox(height: 4),
          opcao(Icons.auto_awesome_outlined, 'Carregar dados de exemplo',
              _exemplo),
          opcao(Icons.delete_outline, 'Apagar todos os dados', _apagar,
              perigo: true),
          const SizedBox(height: 24),
          Text(
            'Movimenta 1.0.0',
            style: t.bodySmall?.copyWith(color: AppCores.cinza),
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
