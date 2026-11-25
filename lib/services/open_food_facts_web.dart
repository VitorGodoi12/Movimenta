import 'package:stokio/services/sugestao_catalogo.dart';

class OpenFoodFacts {
  static const disponivel = false;
  static Future<List<SugestaoCatalogo>> buscarNome(String nome) async => [];

  static Future<({String nome, String categoria, String? marca, String fonte})?>
  buscar(String codigo) async => null;
}
