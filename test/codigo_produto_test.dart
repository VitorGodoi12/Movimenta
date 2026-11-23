import 'package:flutter_test/flutter_test.dart';
import 'package:stokio/utils/codigo_produto.dart';

void main() {
  test('Preserva código desconhecido e identifica o GTIN explícito no QR', () {
    expect(codigoDeProduto('7891234567895'), '7891234567895');
    expect(codigoDeProduto('ITEM-22'), 'ITEM-22');
    final gtin = codigoDeProduto('https://id.gs1.org/01/07891234567895/10/L1');
    expect(gtin, '07891234567895');
    expect(chaveCodigoProduto(gtin!), chaveCodigoProduto('7891234567895'));
    expect(
      codigoDeProduto('https://marca.example/p?ean=7891234567895'),
      '7891234567895',
    );
  });

  test('Ignora links promocionais e números sem identificador de produto', () {
    expect(
      codigoDeProduto('https://marca.example/campanha/7891234567895'),
      isNull,
    );
    expect(
      codigoDeProduto('https://marca.example/?ean=https%3A%2F%2Foutro.example'),
      isNull,
    );
    expect(codigoDeProduto('www.marca.example'), isNull);
  });
}
