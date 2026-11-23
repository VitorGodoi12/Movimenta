import 'package:flutter_test/flutter_test.dart';
import 'package:stokio/models/produto.dart';

void main() {
  test('Restaura a área e as validades sem mudar o saldo total', () {
    final primeira = DateTime(2027, 1, 10);
    final segunda = DateTime(2027, 1, 20);
    final original = Produto(
      id: 'produto',
      nome: 'Suco',
      categoria: 'Bebidas',
      quantidade: 12,
      minimo: 2,
      preco: 5,
    );

    expect(Produto.fromJson(original.toJson()..remove('naLoja')).naLoja, false);
    original
      ..naLoja = true
      ..definirLotes({primeira: 4, segunda: 5, null: 3});

    final restaurado = Produto.fromJson(original.toJson());
    expect(restaurado.naLoja, true);
    expect(restaurado.quantidade, 12);
    expect(restaurado.validade, primeira);
    expect(restaurado.alterarSaldo(-4), {primeira: -4});
    expect(restaurado.validade, segunda);
    expect(restaurado.lotes, {segunda: 5, null: 3});
  });
}
