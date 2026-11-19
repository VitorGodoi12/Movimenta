import 'package:shared_preferences/shared_preferences.dart';

/// Guarda os dados no próprio aparelho (sem servidor).
class Armazenamento {
  Armazenamento._();

  static late SharedPreferences _prefs;

  static Future<void> iniciar() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? ler(String chave) => _prefs.getString(chave);

  static Future<bool> gravar(String chave, String valor) =>
      _prefs.setString(chave, valor);
}
