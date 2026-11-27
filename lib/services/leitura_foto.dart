import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stokio/models/foto_cadastro.dart';
import 'package:stokio/utils/codigo_produto.dart';

class LeituraFoto {
  static final _camera = ImagePicker();

  static Future<FotoCadastro?> capturar(FinalidadeFoto finalidade) async {
    final arquivo = await _camera.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (arquivo == null) return null;
    final entrada = InputImage.fromFilePath(arquivo.path);
    final leitor = TextRecognizer(script: TextRecognitionScript.latin);
    final scanner = finalidade == FinalidadeFoto.produto
        ? BarcodeScanner(
            formats: [
              BarcodeFormat.ean13,
              BarcodeFormat.ean8,
              BarcodeFormat.upca,
              BarcodeFormat.upce,
              BarcodeFormat.itf,
              BarcodeFormat.qrCode,
              BarcodeFormat.dataMatrix,
            ],
          )
        : null;
    try {
      final texto = (await leitor.processImage(entrada)).text;
      final codigos = await scanner?.processImage(entrada) ?? [];
      return FotoCadastro(
        imagem: await arquivo.readAsBytes(),
        texto: texto,
        codigos: {
          for (final codigo in codigos)
            if (codigoDeProduto(codigo.rawValue) case final valor?)
              if (eGtin(valor)) valor,
        }.toList(),
      );
    } finally {
      await leitor.close();
      await scanner?.close();
    }
  }
}
