import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:movimenta/theme/app_theme.dart';

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
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _lido = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aoDetectar(BarcodeCapture captura) {
    if (_lido || ModalRoute.of(context)?.isCurrent != true) return;
    for (final b in captura.barcodes) {
      final valor = b.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        _lido = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, valor);
        return;
      }
    }
  }

  Future<void> _digitar() async {
    final codigo = await showDialog<String>(
      context: context,
      builder: (_) => const _DigitarCodigoDialog(),
    );
    if (codigo != null && codigo.isNotEmpty && mounted) {
      _lido = true;
      Navigator.pop(context, codigo);
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
                scanWindow: area,
                onDetect: _aoDetectar,
                errorBuilder: (context, erro, child) => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Câmera indisponível. Confira a permissão ou digite o código.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppCores.branco),
                    ),
                  ),
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
                      const Text(
                        'Aponte para o código de barras',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppCores.branco,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
