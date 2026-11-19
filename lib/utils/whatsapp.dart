import 'package:url_launcher/url_launcher.dart';

/// Abre uma conversa no WhatsApp com a mensagem pronta.
/// Devolve false se não conseguir abrir.
Future<bool> abrirWhatsapp(String telefone, String mensagem) async {
  var numero = telefone.replaceAll(RegExp(r'\D'), '');
  if (numero.isEmpty) return false;
  // Número brasileiro sem código do país (DDD + número).
  if (numero.length <= 11) numero = '55$numero';

  final uri = Uri.parse(
    'https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
