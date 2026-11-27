import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stokio/models/foto_cadastro.dart';

FotoCadastro foto(String texto) =>
    FotoCadastro(imagem: Uint8List(0), texto: texto, codigos: []);

void main() {
  test('Sugere a data mais recente e preserva mês e ano', () {
    final resultado = foto('FAB 09.11.26 VAL 04/2028\n31/02/2028\n28/03/28');
    expect(resultado.validades.first, (
      data: DateTime(2028, 4, 30),
      rotulo: '04/2028',
    ));
    expect(resultado.validades.map((v) => v.data), [
      DateTime(2028, 4, 30),
      DateTime(2028, 3, 28),
      DateTime(2026, 11, 9),
    ]);
  });

  test('Distingue preços de medidas e parcelas', () {
    final resultado = foto(
      'NORMAL R\$ 12,99\nATACADO 10,49\nVOLUME 1,50 L\n3 x R\$ 5,90',
    );
    expect(resultado.precos.map((p) => p.valor), [12.99, 10.49]);
  });

  test('Lê unidades da embalagem sem interpretar a medida', () {
    expect(foto('6 GARRAFAS DE 2 L').unidadesPorVolume, 6);
    expect(foto('VOLUME 2 L').unidadesPorVolume, isNull);
  });
}
