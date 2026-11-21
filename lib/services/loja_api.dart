import 'dart:convert';

import 'package:http/http.dart' as http;

class LojaApi {
  LojaApi(String endereco)
    : base = Uri.parse(endereco.trim().replaceFirst(RegExp(r'/+$'), '')) {
    if (!base.hasAuthority ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' &&
            !(base.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(base.host)))) {
      throw const FormatException('Informe o endereço HTTPS do servidor.');
    }
  }

  final Uri base;
  String? token;

  Future<Map<String, dynamic>> chamar(
    String caminho, [
    Map<String, Object?>? dados,
  ]) async {
    final uri = base.replace(path: '${base.path}/api/$caminho');
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      if (dados != null) 'Content-Type': 'application/json',
    };
    final resposta =
        await (dados == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(dados)))
            .timeout(const Duration(seconds: 15));
    final json =
        jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    if (resposta.statusCode != 200) {
      if (resposta.statusCode == 401 && token != null) token = null;
      throw LojaErro(json['error'] as String? ?? 'Erro no servidor.');
    }
    return json;
  }
}

class LojaErro implements Exception {
  const LojaErro(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

List<Map<String, dynamic>> registros(
  Map<String, dynamic> resposta,
  String campo,
) => (resposta[campo] as List).cast<Map<String, dynamic>>();
