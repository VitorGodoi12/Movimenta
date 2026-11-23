import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/codigo_produto.dart';
import 'package:stokio/widgets/dialogos.dart';

/// Abre a câmera e devolve o código lido (ou digitado). Nulo se cancelar.
Future<String?> lerCodigo(BuildContext context) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => const ScannerScreen(),
      fullscreenDialog: true,
    ),
  );
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    autoZoom: true,
  );
  bool _lido = false;
  bool _avisouLink = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _processar(String codigo) {
    if (!mounted || _lido) return;
    _lido = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, codigo);
  }

  void _aoDetectar(BarcodeCapture captura) {
    if (!mounted || _lido || ModalRoute.of(context)?.isCurrent != true) return;
    for (final b in captura.barcodes) {
      final codigo = codigoDeProduto(b.rawValue);
      if (codigo != null) {
        _processar(codigo);
        return;
      }
    }
    if (!_avisouLink &&
        captura.barcodes.any((b) => b.rawValue?.isNotEmpty == true)) {
      _avisouLink = true;
      avisar(
        context,
        'QR sem código de produto. Leia as barras ou digite o número da embalagem.',
      );
    }
  }

  Future<void> _digitar() async {
    final codigo = await showDialog<String>(
      context: context,
      builder: (_) => const _DigitarCodigoDialog(),
    );
    if (codigo != null && codigo.isNotEmpty && mounted) {
      final normalizado = codigoDeProduto(codigo);
      if (normalizado == null) {
        avisar(context, 'Digite o código impresso na embalagem.');
        return;
      }
      _processar(normalizado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estiloBotao = IconButton.styleFrom(
      backgroundColor: AppCores.branco,
      foregroundColor: AppCores.preto,
    );

    return Scaffold(
      backgroundColor: AppCores.preto,
      body: LayoutBuilder(
        builder: (context, limites) {
          final area = Rect.fromCenter(
            center: limites.biggest.center(Offset.zero),
            width: (limites.maxWidth * 0.82).clamp(0.0, 290.0).toDouble(),
            height: (limites.maxHeight * 0.4).clamp(0.0, 190.0).toDouble(),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                fit: BoxFit.contain,
                tapToFocus: true,
                onDetect: _aoDetectar,
                errorBuilder: (context, erro) => avisoCameraLeitor(
                  erro,
                  tentarNovamente: () => _controller.start(),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: area.width,
                    height: area.height,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppCores.roxo, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton.filled(
                            tooltip: 'Fechar',
                            style: estiloBotao,
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          ValueListenableBuilder<MobileScannerState>(
                            valueListenable: _controller,
                            builder: (context, estado, _) => IconButton.filled(
                              tooltip: 'Lanterna',
                              style: estiloBotao,
                              icon: Icon(
                                estado.torchState == TorchState.on
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                              ),
                              onPressed:
                                  estado.torchState == TorchState.unavailable
                                  ? null
                                  : _controller.toggleTorch,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Trocar câmera',
                            style: estiloBotao,
                            icon: const Icon(Icons.cameraswitch_outlined),
                            onPressed: () => _controller.switchCamera(),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Aponte para o código de barras. Toque na câmera para focar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppCores.branco,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _digitar,
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Digitar o código'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DigitarCodigoDialog extends StatefulWidget {
  const _DigitarCodigoDialog();

  @override
  State<_DigitarCodigoDialog> createState() => _DigitarCodigoDialogState();
}

class _DigitarCodigoDialogState extends State<_DigitarCodigoDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Digitar o código'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Código de barras'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Usar código'),
        ),
      ],
    );
  }
}

Widget avisoCameraLeitor(
  MobileScannerException erro, {
  required VoidCallback tentarNovamente,
}) {
  final mensagem = switch (erro.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Permita o acesso à câmera nas configurações do aparelho.',
    MobileScannerErrorCode.unsupported =>
      'Este aparelho não disponibilizou uma câmera para leitura.',
    _ => 'Não foi possível iniciar a câmera.',
  };

  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          TextButton(
            onPressed: tentarNovamente,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
